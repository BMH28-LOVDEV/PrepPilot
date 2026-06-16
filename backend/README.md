# PrepPilot Backend

FastAPI backend for the PrepPilot iOS app. Render should run `main:app`, and
`/openapi.json` should list the study endpoints below.

## Required Environment Variables

Set these in Render:

```text
OPENAI_API_KEY=sk-...
CLIENT_API_KEY=<same value as Secrets.clientAPIKey in the iOS app>
OPENAI_MODEL=gpt-4.1-mini
```

`APP_API_KEY` is also accepted as an alias for `CLIENT_API_KEY`.

## Render

Recommended service settings:

```text
Environment: Docker
Root Directory: .
Dockerfile Path: Dockerfile
Health Check Path: /healthz
Branch: main
```

The root Dockerfile copies this `backend/` folder and starts:

```bash
uvicorn main:app --host 0.0.0.0 --port ${PORT:-10000}
```

## Endpoints Used By The iOS App

```text
GET  /healthz
GET  /health
GET  /api/health
POST /api/generate-notes
POST /api/generate-flashcards
POST /api/generate-quiz
POST /api/generate-study-guide
POST /api/answer
```

The backend accepts either auth header:

```text
Authorization: Bearer <CLIENT_API_KEY>
X-API-Key: <CLIENT_API_KEY>
```

## Local Verification

From the repo root:

```bash
cd backend
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
CLIENT_API_KEY=dev-key OPENAI_API_KEY=sk-your-key uvicorn main:app --host 0.0.0.0 --port 8787
```

In another terminal:

```bash
curl -s http://127.0.0.1:8787/openapi.json | python -m json.tool

curl -i http://127.0.0.1:8787/healthz

curl -i -X POST http://127.0.0.1:8787/api/generate-notes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dev-key" \
  -H "X-API-Key: dev-key" \
  -d '{"transcript":"Cells use membranes to regulate transport.","lecture_title":"Cell Biology"}'
```

## Deployed Verification

```bash
export BASE=https://preppilot-official-dockersetup.onrender.com
export KEY="<same client key used by the iOS app>"

curl -i "$BASE/healthz"

curl -s "$BASE/openapi.json" | python -c 'import sys,json; print("\n".join(sorted(json.load(sys.stdin).get("paths",{}))))'

curl -i -X POST "$BASE/api/generate-notes" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -H "X-API-Key: $KEY" \
  -d '{"transcript":"Hello world","lecture_title":"Intro"}'
```
