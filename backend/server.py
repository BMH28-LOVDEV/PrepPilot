#!/usr/bin/env python3
import json
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


def load_env(env_path):
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        trimmed = line.strip()
        if not trimmed or trimmed.startswith("#") or "=" not in trimmed:
            continue
        key, value = trimmed.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


BASE_DIR = Path(__file__).resolve().parent
load_env(BASE_DIR / ".env")

PORT = int(os.environ.get("PORT", "8787"))
HOST = os.environ.get("BACKEND_HOST", "0.0.0.0")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-4.1-mini")
OPENAI_TIMEOUT_SECONDS = int(os.environ.get("OPENAI_TIMEOUT_SECONDS", "180"))
OPENAI_MAX_ATTEMPTS = int(os.environ.get("OPENAI_MAX_ATTEMPTS", "3"))


SCHEMAS = {
    "notes": {
        "type": "object",
        "additionalProperties": False,
        "required": ["title", "detailedNotes", "conciseSummary", "keyTakeaways", "vocabularyTerms", "importantConcepts"],
        "properties": {
            "title": {"type": "string"},
            "detailedNotes": {"type": "string"},
            "conciseSummary": {"type": "string"},
            "keyTakeaways": {"type": "string"},
            "vocabularyTerms": {"type": "string"},
            "importantConcepts": {"type": "string"},
        },
    },
    "flashcards": {
        "type": "object",
        "additionalProperties": False,
        "required": ["cards"],
        "properties": {
            "cards": {
                "type": "array",
                "minItems": 1,
                "maxItems": 30,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["front", "back"],
                    "properties": {
                        "front": {"type": "string"},
                        "back": {"type": "string"},
                    },
                },
            },
        },
    },
    "quiz": {
        "type": "object",
        "additionalProperties": False,
        "required": ["title", "questions"],
        "properties": {
            "title": {"type": "string"},
            "questions": {
                "type": "array",
                "minItems": 1,
                "maxItems": 25,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["kind", "prompt", "options", "correctAnswer", "explanation"],
                    "properties": {
                        "kind": {"type": "string", "enum": ["multipleChoice", "trueFalse", "matching", "shortAnswer"]},
                        "prompt": {"type": "string"},
                        "options": {"type": "array", "items": {"type": "string"}},
                        "correctAnswer": {"type": "string"},
                        "explanation": {"type": "string"},
                    },
                },
            },
        },
    },
    "study_guide": {
        "type": "object",
        "additionalProperties": False,
        "required": ["title", "examReview", "topicSummaries", "importantConcepts", "keyDefinitions"],
        "properties": {
            "title": {"type": "string"},
            "examReview": {"type": "string"},
            "topicSummaries": {"type": "string"},
            "importantConcepts": {"type": "string"},
            "keyDefinitions": {"type": "string"},
        },
    },
    "answer": {
        "type": "object",
        "additionalProperties": False,
        "required": ["content", "sources"],
        "properties": {
            "content": {"type": "string"},
            "sources": {"type": "array", "items": {"type": "string"}},
        },
    },
}


class PrepPilotHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_json(204, {})

    def do_GET(self):
        if self.path in ("/health", "/api/health"):
            self.send_json(200, {
                "ok": True,
                "model": OPENAI_MODEL,
                "hasOpenAIKey": bool(OPENAI_API_KEY),
            })
            return
        self.send_json(404, {"error": "Route not found."})

    def do_POST(self):
        try:
            body = self.read_json_body()

            if self.path == "/api/generate-notes":
                result = generate_structured(
                    schema_name="prep_pilot_notes",
                    schema=SCHEMAS["notes"],
                    instructions="You are PrepPilot, a precise study assistant. Create high-quality study notes from lecture text. Return concise but useful JSON only.",
                    user_text=f"Lecture title: {body.get('lectureTitle') or 'Lecture'}\n\nTranscript or notes:\n{body.get('transcript') or ''}",
                )
                self.send_json(200, result)
                return

            if self.path == "/api/generate-flashcards":
                preferences = normalized_preferences(body)
                result = generate_structured(
                    schema_name="prep_pilot_flashcards",
                    schema=SCHEMAS["flashcards"],
                    instructions=f"Create exactly {preferences['flashcardCount']} exam-useful flashcards from the lecture text and notes. Make fronts specific and backs clear enough for studying. Return exactly {preferences['flashcardCount']} cards unless the source is too short.",
                    user_text=material_prompt(body),
                )
                self.send_json(200, result["cards"])
                return

            if self.path == "/api/generate-quiz":
                preferences = normalized_preferences(body)
                allowed_kinds = ", ".join(preferences["quizKinds"])
                result = generate_structured(
                    schema_name="prep_pilot_quiz",
                    schema=SCHEMAS["quiz"],
                    instructions=f"Create exactly {preferences['quizQuestionCount']} quiz questions using only the provided lecture context. Use only these question kinds: {allowed_kinds}. Multiple choice questions need exactly four options. True/false questions need options True and False. Matching questions should ask which term matches a definition and include selectable term options. Short answer questions need an answer key that describes the expected idea, not wording that must be copied exactly.",
                    user_text=material_prompt(body),
                )
                self.send_json(200, result)
                return

            if self.path == "/api/generate-study-guide":
                result = generate_structured(
                    schema_name="prep_pilot_study_guide",
                    schema=SCHEMAS["study_guide"],
                    instructions="Create an exam review sheet, topic summaries, important concepts, and key definitions using only the provided lecture context.",
                    user_text=material_prompt(body),
                )
                self.send_json(200, result)
                return

            if self.path == "/api/chat":
                result = generate_structured(
                    schema_name="prep_pilot_note_answer",
                    schema=SCHEMAS["answer"],
                    instructions="Answer only from the supplied note context. If the answer is not in the notes, say that clearly. Include short source labels from the notes when possible.",
                    user_text=f"Question:\n{body.get('question') or ''}\n\nNote context:\n{body.get('noteContext') or ''}",
                )
                self.send_json(200, result)
                return

            self.send_json(404, {"error": "Route not found."})
        except BackendError as error:
            self.send_json(error.status_code, {"error": str(error)})
        except Exception as error:
            self.send_json(500, {"error": str(error)})

    def read_json_body(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        raw_body = self.rfile.read(length).decode("utf-8")
        try:
            return json.loads(raw_body)
        except json.JSONDecodeError:
            raise BackendError("Request body must be valid JSON.", 400)

    def send_json(self, status_code, payload):
        encoded = b"" if status_code == 204 else json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        if encoded:
            self.wfile.write(encoded)

    def log_message(self, format, *args):
        print(f"{self.address_string()} - {format % args}")


class BackendError(Exception):
    def __init__(self, message, status_code=500):
        super().__init__(message)
        self.status_code = status_code


def material_prompt(body):
    preferences = normalized_preferences(body)
    return "\n".join([
        "Transcript or uploaded notes:",
        body.get("transcript") or "",
        "",
        "Generated notes:",
        json.dumps(body.get("notes") or {}, indent=2),
        "",
        "User generation preferences:",
        json.dumps(preferences, indent=2),
    ])


def normalized_preferences(body):
    raw = body.get("preferences") or {}
    valid_kinds = ["multipleChoice", "trueFalse", "matching", "shortAnswer"]
    requested_kinds = raw.get("quizKinds") or valid_kinds
    quiz_kinds = [kind for kind in requested_kinds if kind in valid_kinds]
    if not quiz_kinds:
        quiz_kinds = valid_kinds

    return {
        "flashcardCount": clamp_int(raw.get("flashcardCount"), 4, 30, 12),
        "quizQuestionCount": clamp_int(raw.get("quizQuestionCount"), 3, 25, 8),
        "quizKinds": quiz_kinds,
    }


def clamp_int(value, minimum, maximum, default):
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default
    return max(minimum, min(maximum, parsed))


def generate_structured(schema_name, schema, instructions, user_text):
    if not OPENAI_API_KEY:
        raise BackendError("Missing OPENAI_API_KEY. Add it to backend/.env, then restart the server.", 500)

    request_body = {
        "model": OPENAI_MODEL,
        "input": [
            {"role": "system", "content": instructions},
            {"role": "user", "content": user_text},
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": schema_name,
                "strict": True,
                "schema": schema,
            },
        },
    }

    payload = None
    request_data = json.dumps(request_body).encode("utf-8")

    for attempt in range(1, OPENAI_MAX_ATTEMPTS + 1):
        request = urllib.request.Request(
            "https://api.openai.com/v1/responses",
            data=request_data,
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            method="POST",
        )

        try:
            print(f"OpenAI request {schema_name}, attempt {attempt}/{OPENAI_MAX_ATTEMPTS}")
            with urllib.request.urlopen(request, timeout=OPENAI_TIMEOUT_SECONDS) as response:
                payload = json.loads(response.read().decode("utf-8"))
            print(f"OpenAI request {schema_name} succeeded")
            break
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8")
            try:
                message = json.loads(detail).get("error", {}).get("message") or detail
            except json.JSONDecodeError:
                message = detail

            if should_retry_openai_error(error.code, message, attempt):
                wait_before_retry(attempt, message)
                continue

            raise BackendError(message, error.code)
        except urllib.error.URLError as error:
            message = str(error.reason)
            if attempt < OPENAI_MAX_ATTEMPTS:
                wait_before_retry(attempt, message)
                continue
            raise BackendError(f"OpenAI connection failed: {message}", 504)

    if payload is None:
        raise BackendError("OpenAI request failed before returning a response.", 504)

    output_text = extract_output_text(payload)
    if not output_text:
        raise BackendError("OpenAI response did not include output text.")

    try:
        return json.loads(strip_code_fence(output_text))
    except json.JSONDecodeError:
        raise BackendError("OpenAI returned text that could not be parsed as JSON.")


def extract_output_text(payload):
    if isinstance(payload.get("output_text"), str):
        return payload["output_text"]

    parts = []
    for item in payload.get("output", []):
        for content in item.get("content", []):
            if isinstance(content.get("text"), str):
                parts.append(content["text"])
            if isinstance(content.get("output_text"), str):
                parts.append(content["output_text"])
    return "\n".join(parts).strip()


def strip_code_fence(value):
    text = value.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def should_retry_openai_error(status_code, message, attempt):
    if attempt >= OPENAI_MAX_ATTEMPTS:
        return False
    retryable_status = status_code in (408, 500, 502, 503, 504)
    retryable_message = "upstream connect error" in message.lower() or "connection timed out" in message.lower()
    return retryable_status or retryable_message


def wait_before_retry(attempt, message):
    wait_time = min(2 * attempt, 6)
    print(f"OpenAI request failed transiently: {message}")
    print(f"Retrying in {wait_time}s")
    time.sleep(wait_time)


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), PrepPilotHandler)
    print(f"PrepPilot local AI backend running at http://{HOST}:{PORT}")
    print(f"Real-device URL usually uses your Mac IP, for example http://192.168.x.x:{PORT}")
    print(f"OpenAI key loaded: {'yes' if OPENAI_API_KEY else 'no'}")
    server.serve_forever()
