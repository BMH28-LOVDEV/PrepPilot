FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir -r requirements.txt

COPY . .

# Print Python version at start so we can see it's 3.11, then boot uvicorn
CMD ["sh", "-c", "python -V && python -m uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
