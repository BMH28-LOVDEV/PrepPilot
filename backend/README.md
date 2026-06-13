# PrepPilot Local AI Backend

This local server lets the iOS simulator call OpenAI through your Mac instead of putting an API key in the app.

## Setup

```bash
cd /Users/bmh/Desktop/PrepPilot/backend
cp .env.example .env
open -e .env
```

Paste your OpenAI key into `.env`:

```bash
OPENAI_API_KEY=sk-your-real-key-here
OPENAI_MODEL=gpt-4.1-mini
PORT=8787
BACKEND_HOST=0.0.0.0
```

## Run

```bash
cd /Users/bmh/Desktop/PrepPilot/backend
python3 server.py
```

Keep that Terminal window open while testing PrepPilot in the iOS Simulator.

For real iPhone testing, keep the iPhone and Mac on the same Wi-Fi network. The iPhone app must call your Mac's local IP address. This project is currently pointed at:

```text
http://192.168.11.130:8787/api
```

If your Mac's IP changes, update `BackendStudyAIService` in `PrepPilot/ContentView.swift` and the matching `Info.plist` ATS exception.

## Health Check

In a second Terminal window:

```bash
curl http://127.0.0.1:8787/api/health
```

You want to see:

```json
{"ok": true, "model": "gpt-4.1-mini", "hasOpenAIKey": true}
```

## Test Notes Generation

```bash
curl -X POST http://127.0.0.1:8787/api/generate-notes \
  -H "Content-Type: application/json" \
  -d '{"lectureTitle":"Cell Biology","transcript":"Cells use membranes to regulate transport. Mitochondria generate ATP through cellular respiration."}'
```
