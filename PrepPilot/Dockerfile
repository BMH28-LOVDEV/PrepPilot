# Root-level Dockerfile to deploy the backend on Render from this repo
# It builds a FastAPI (uvicorn) service using the code under the backend/ directory.

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install backend dependencies
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend app code
COPY backend/ ./

# Render provides $PORT at runtime; default to 10000 for local runs
ENV PORT=10000
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-10000}"]
