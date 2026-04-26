# Contributing to ResilientNet

Quick rules for our hackathon team.

## Before You Start

1. Pull latest `main` before creating any branch
2. Check that `flutter pub get` works without errors
3. Confirm the app still runs: `flutter run -d chrome`

## Branch Naming

`feature/<short-description>` — new work
`fix/<short-description>` — bug fix
`refactor/<short-description>` — cleanup

Examples:
- `feature/firebase-wiring`
- `feature/gemini-parser`
- `fix/ops-dashboard-overflow`

## Pull Request Checklist

Before opening a PR:
- [ ] `flutter analyze` passes (no errors, warnings okay for now)
- [ ] `flutter run -d chrome` launches successfully
- [ ] All 3 tabs still render without crashes
- [ ] No API keys or secrets committed (check `git diff`)
- [ ] README updated if you added new setup steps

## Code Style

- Use `setState` for local UI state — don't add Provider/Riverpod this week
- Keep widget files under 600 lines — split if larger
- Extract reusable widgets to `lib/widgets/`
- Comment non-obvious logic, skip obvious ones

## Communication

- Blocked for 2+ hours? Post in team chat.
- Merging to `main`? Announce in chat.
- Breaking change? Tag everyone.

## What Not to Do

- Don't push directly to `main`
- Don't commit `.env`, `firebase_options.dart`, or API keys
- Don't force-push shared branches
- Don't delete someone else's branch without asking
