/**
 * firebase/functions/index.js
 *
 * Cloud Functions that run serverlessly alongside your Flutter app.
 *
 * WHAT THESE DO:
 *  1. notifyOnCriticalDisruption  — When a critical disruption is written to
 *     Firestore by realtime_poller.py, this fires instantly and sends an FCM
 *     push notification to the ops team's devices.
 *
 *  2. autoResolveOldDisruptions   — Runs hourly. Marks disruptions older than
 *     6 hours as 'resolved' so the live feed stays clean.
 *
 *  3. scheduledPoll               — Optional: runs the Python poll on a Cloud
 *     Scheduler instead of needing the Python process running 24/7.
 *     Only needed if you're not running the backend server continuously.
 *
 * DEPLOY:
 *  cd firebase/functions
 *  npm install
 *  firebase deploy --only functions
 *
 * SETUP:
 *  firebase init functions    (choose JavaScript)
 *  Then replace index.js with this file.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();


// ── 1. NOTIFY ON CRITICAL DISRUPTION ────────────────────────────────────────
// Triggers whenever a new document is written to /disruptions/{id}
// Sends FCM push to all ops team devices if severity >= 0.6

exports.notifyOnCriticalDisruption = functions.firestore
  .document("disruptions/{disruptionId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    // Only notify for medium severity and above
    if (!data || data.severity < 0.6) {
      console.log(`Skipping notification — severity ${data?.severity} < 0.6`);
      return null;
    }

    const severityLabel =
      data.severity >= 0.8 ? "🔴 CRITICAL" :
      data.severity >= 0.6 ? "🟠 HIGH" : "🟡 MEDIUM";

    const title = `${severityLabel} Supply Chain Disruption`;
    const body = data.headline
      ? data.headline.substring(0, 120)
      : `Disruption at ${data.location || "unknown location"}`;

    // Build the FCM message
    const message = {
      notification: { title, body },
      data: {
        disruption_id: context.params.disruptionId,
        severity: String(data.severity),
        type: data.type || "other",
        location: data.location || "",
        shipments_at_risk: String(data.shipments_at_risk || 0),
        reroutes_available: String(data.reroutes_available || 0),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      // Send to the "ops_alerts" topic — subscribe devices to this topic
      topic: "ops_alerts",
      android: {
        priority: data.severity >= 0.8 ? "high" : "normal",
        notification: {
          sound: data.severity >= 0.8 ? "alarm" : "default",
          channelId: "resilientnet_disruptions",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: data.severity >= 0.8 ? "alarm.caf" : "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await messaging.send(message);
      console.log(`✅ FCM sent for disruption ${context.params.disruptionId}: ${response}`);

      // Also send targeted notification to driver topic if location matched
      if (data.location && data.type === "strike" || data.type === "closure") {
        const driverMessage = {
          notification: {
            title: "⚠️ Route Alert",
            body: `Avoid ${data.location}: ${data.type}. Check app for alternatives.`,
          },
          data: { disruption_id: context.params.disruptionId, screen: "driver" },
          topic: "driver_alerts",
        };
        await messaging.send(driverMessage);
        console.log(`✅ Driver FCM sent for location ${data.location}`);
      }

      return response;
    } catch (err) {
      console.error(`❌ FCM send failed: ${err}`);
      return null;
    }
  });


// ── 2. AUTO-RESOLVE OLD DISRUPTIONS ─────────────────────────────────────────
// Runs every hour. Marks active disruptions older than 6h as resolved.
// This keeps the live feed showing only current issues.

exports.autoResolveOldDisruptions = functions.pubsub
  .schedule("every 60 minutes")
  .onRun(async (_context) => {
    const cutoff = new Date();
    cutoff.setHours(cutoff.getHours() - 6); // 6 hours ago

    const snap = await db
      .collection("disruptions")
      .where("status", "==", "active")
      .where("created_at", "<=", admin.firestore.Timestamp.fromDate(cutoff))
      .get();

    if (snap.empty) {
      console.log("No old disruptions to resolve");
      return null;
    }

    const batch = db.batch();
    snap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        status: "resolved",
        resolved_at: admin.firestore.FieldValue.serverTimestamp(),
        resolve_reason: "auto_expired_6h",
      });
    });

    await batch.commit();
    console.log(`✅ Auto-resolved ${snap.size} old disruptions`);

    // Update the realtime_status active count
    await db.collection("realtime_status").doc("latest").update({
      active_disruptions: admin.firestore.FieldValue.increment(-snap.size),
    });

    return null;
  });


// ── 3. SCHEDULED POLL (optional — only if Python server isn't running 24/7) ──
// Calls your backend's POST /realtime/poll_now endpoint on a schedule.
// Useful for Cloud Run deployments that scale to zero.

const BACKEND_URL = functions.config().backend?.url || "";

exports.scheduledPoll = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async (_context) => {
    if (!BACKEND_URL) {
      console.log("BACKEND_URL not configured — skipping scheduled poll");
      console.log("Set it with: firebase functions:config:set backend.url=https://your-backend.run.app");
      return null;
    }

    try {
      const fetch = require("node-fetch");
      const response = await fetch(`${BACKEND_URL}/realtime/poll_now`, {
        method: "POST",
        timeout: 30000,
      });

      if (response.ok) {
        const data = await response.json();
        console.log(`✅ Poll triggered: ${data.message}`);
      } else {
        console.error(`❌ Poll failed: ${response.status} ${response.statusText}`);
      }
    } catch (err) {
      console.error(`❌ Could not reach backend: ${err}`);
    }

    return null;
  });


// ── 4. SUBSCRIBE DEVICE TO TOPICS (callable function) ────────────────────────
// Call from Flutter when user logs in to subscribe their device token
// to the right notification topics based on their role.

exports.subscribeToTopics = functions.https.onCall(async (data, context) => {
  const { token, role } = data;

  if (!token) throw new functions.https.HttpsError("invalid-argument", "token required");

  const topics = ["ops_alerts"]; // everyone gets ops alerts
  if (role === "driver") topics.push("driver_alerts");

  const results = await Promise.allSettled(
    topics.map((topic) => messaging.subscribeToTopic([token], topic))
  );

  console.log(`Subscribed ${token.slice(0, 20)}... to topics: ${topics.join(", ")}`);
  return { subscribed: topics };
});
