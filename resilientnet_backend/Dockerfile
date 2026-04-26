FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (better Docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code and data
COPY app/ ./app/
COPY data/ ./data/

# Cloud Run sets PORT env var
ENV PORT=8080

# Run with uvicorn
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
