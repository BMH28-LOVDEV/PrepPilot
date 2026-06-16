FROM python:3.12-slim
WORKDIR /app

RUN pip install --no-cache-dir fastapi==0.110.0 uvicorn==0.29.0

COPY app.py .

ENV PORT=10000
EXPOSE 10000

CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT}"]
