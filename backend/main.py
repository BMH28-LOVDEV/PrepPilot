import hmac
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - Render installs python-dotenv from requirements.txt
    load_dotenv = None


BASE_DIR = Path(__file__).resolve().parent
if load_dotenv:
    load_dotenv(BASE_DIR / ".env")


CLIENT_API_KEY = (os.getenv("APP_API_KEY") or os.getenv("CLIENT_API_KEY") or "").strip()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "").strip()
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1-mini").strip()
OPENAI_TIMEOUT_SECONDS = int(os.getenv("OPENAI_TIMEOUT_SECONDS", "180"))
OPENAI_MAX_ATTEMPTS = int(os.getenv("OPENAI_MAX_ATTEMPTS", "3"))
OPENAI_MAX_OUTPUT_TOKENS = int(os.getenv("OPENAI_MAX_OUTPUT_TOKENS", "5000"))


app = FastAPI(title="PrepPilot Backend", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
)


SCHEMAS: dict[str, dict[str, Any]] = {
    "notes": {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "title",
            "detailedNotes",
            "conciseSummary",
            "keyTakeaways",
            "vocabularyTerms",
            "importantConcepts",
        ],
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
                        "kind": {
                            "type": "string",
                            "enum": ["multipleChoice", "trueFalse", "matching", "shortAnswer"],
                        },
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


class BackendError(Exception):
    def __init__(self, message: str, status_code: int = 500):
        super().__init__(message)
        self.status_code = status_code


@app.exception_handler(BackendError)
async def backend_error_handler(_request: Request, error: BackendError):
    return JSONResponse(status_code=error.status_code, content={"error": str(error)})


@app.exception_handler(Exception)
async def unexpected_error_handler(_request: Request, error: Exception):
    return JSONResponse(status_code=500, content={"error": str(error)})


@app.get("/")
@app.get("/health")
@app.get("/healthz")
@app.get("/api/health")
@app.get("/api/healthz")
async def health():
    return {
        "ok": True,
        "status": "ok",
        "model": OPENAI_MODEL,
        "hasOpenAIKey": bool(OPENAI_API_KEY),
        "authConfigured": bool(CLIENT_API_KEY),
    }


@app.post("/api/generate-notes")
@app.post("/api/generate_notes", include_in_schema=False)
async def generate_notes(request: Request):
    require_client_auth(request)
    body = await read_json_body(request)
    transcript = text_field(body, "transcript")
    lecture_title = text_field(body, "lecture_title", "lectureTitle", "title", default="Lecture")

    return generate_structured(
        schema_name="prep_pilot_notes",
        schema=SCHEMAS["notes"],
        instructions=(
            "You are PrepPilot, a precise study assistant. Create high-quality study notes "
            "from lecture text. Return JSON only."
        ),
        user_text="\n".join(
            [
                f"Lecture title: {lecture_title}",
                "",
                "Transcript or notes:",
                transcript,
            ]
        ),
    )


@app.post("/api/generate-flashcards")
@app.post("/api/generate_flashcards", include_in_schema=False)
async def generate_flashcards(request: Request):
    require_client_auth(request)
    body = await read_json_body(request)
    preferences = normalized_preferences(body)

    result = generate_structured(
        schema_name="prep_pilot_flashcards",
        schema=SCHEMAS["flashcards"],
        instructions=(
            f"Create exactly {preferences['flashcardCount']} exam-useful flashcards from the "
            "lecture text and notes. Make fronts specific and backs clear enough for studying. "
            f"Return exactly {preferences['flashcardCount']} cards unless the source is too short."
        ),
        user_text=material_prompt(body),
    )
    return result["cards"]


@app.post("/api/generate-quiz")
@app.post("/api/generate_quiz", include_in_schema=False)
async def generate_quiz(request: Request):
    require_client_auth(request)
    body = await read_json_body(request)
    preferences = normalized_preferences(body)
    allowed_kinds = ", ".join(preferences["quizKinds"])

    return generate_structured(
        schema_name="prep_pilot_quiz",
        schema=SCHEMAS["quiz"],
        instructions=(
            f"Create exactly {preferences['quizQuestionCount']} quiz questions using only the "
            f"provided lecture context. Use only these question kinds: {allowed_kinds}. Multiple "
            "choice questions need exactly four options. True/false questions need options True "
            "and False. Matching questions should ask which term matches a definition and include "
            "selectable term options. Short answer questions need an answer key that describes "
            "the expected idea, not wording that must be copied exactly."
        ),
        user_text=material_prompt(body),
    )


@app.post("/api/generate-study-guide")
@app.post("/api/generate_study_guide", include_in_schema=False)
async def generate_study_guide(request: Request):
    require_client_auth(request)
    body = await read_json_body(request)

    return generate_structured(
        schema_name="prep_pilot_study_guide",
        schema=SCHEMAS["study_guide"],
        instructions=(
            "Create an exam review sheet, topic summaries, important concepts, and key "
            "definitions using only the provided lecture context."
        ),
        user_text=material_prompt(body),
    )


@app.post("/api/answer")
@app.post("/api/chat", include_in_schema=False)
async def answer(request: Request):
    require_client_auth(request)
    body = await read_json_body(request)
    question = text_field(body, "question", "question_text", "questionText")
    note_context = text_field(body, "note_context", "noteContext", "context")

    return generate_structured(
        schema_name="prep_pilot_note_answer",
        schema=SCHEMAS["answer"],
        instructions=(
            "Answer only from the supplied note context. If the answer is not in the notes, "
            "say that clearly. Include short source labels from the notes when possible."
        ),
        user_text="\n".join(
            [
                "Question:",
                question,
                "",
                "Note context:",
                note_context,
            ]
        ),
    )


async def read_json_body(request: Request) -> dict[str, Any]:
    try:
        payload = await request.json()
    except json.JSONDecodeError:
        raise BackendError("Request body must be valid JSON.", 400)

    if payload is None:
        return {}
    if not isinstance(payload, dict):
        raise BackendError("Request body must be a JSON object.", 400)
    return payload


def require_client_auth(request: Request) -> None:
    if not CLIENT_API_KEY:
        raise BackendError("Server is missing CLIENT_API_KEY or APP_API_KEY.", 500)

    authorization = request.headers.get("authorization", "")
    bearer_key = ""
    if authorization.lower().startswith("bearer "):
        bearer_key = authorization[7:].strip()

    x_api_key = request.headers.get("x-api-key", "").strip()
    if hmac.compare_digest(bearer_key, CLIENT_API_KEY) or hmac.compare_digest(x_api_key, CLIENT_API_KEY):
        return

    raise BackendError("Unauthorized.", 401)


def text_field(body: dict[str, Any], *names: str, default: str = "") -> str:
    for name in names:
        value = body.get(name)
        if value is None:
            continue
        if isinstance(value, str):
            return value
        return str(value)
    return default


def value_field(body: dict[str, Any], *names: str, default: Any = None) -> Any:
    for name in names:
        if name in body and body[name] is not None:
            return body[name]
    return default


def material_prompt(body: dict[str, Any]) -> str:
    preferences = normalized_preferences(body)
    notes = value_field(body, "notes", default={})

    return "\n".join(
        [
            "Transcript or uploaded notes:",
            text_field(body, "transcript"),
            "",
            "Generated notes:",
            json.dumps(notes, indent=2),
            "",
            "User generation preferences:",
            json.dumps(preferences, indent=2),
        ]
    )


def normalized_preferences(body: dict[str, Any]) -> dict[str, Any]:
    raw = value_field(body, "preferences", default={})
    if not isinstance(raw, dict):
        raw = {}

    valid_kinds = ["multipleChoice", "trueFalse", "matching", "shortAnswer"]
    requested_kinds = value_field(raw, "quizKinds", "quiz_kinds", default=valid_kinds)
    quiz_kinds = [kind for kind in requested_kinds if kind in valid_kinds] if isinstance(requested_kinds, list) else []
    if not quiz_kinds:
        quiz_kinds = valid_kinds

    return {
        "flashcardCount": clamp_int(value_field(raw, "flashcardCount", "flashcard_count"), 4, 30, 12),
        "quizQuestionCount": clamp_int(value_field(raw, "quizQuestionCount", "quiz_question_count"), 3, 25, 8),
        "quizKinds": quiz_kinds,
    }


def clamp_int(value: Any, minimum: int, maximum: int, default: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default
    return max(minimum, min(maximum, parsed))


def generate_structured(schema_name: str, schema: dict[str, Any], instructions: str, user_text: str) -> Any:
    if not OPENAI_API_KEY:
        raise BackendError("Server is missing OPENAI_API_KEY.", 500)

    request_body: dict[str, Any] = {
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
        "max_output_tokens": OPENAI_MAX_OUTPUT_TOKENS,
    }

    payload = request_openai(request_body, schema_name)
    output_text = extract_output_text(payload)
    if not output_text:
        raise BackendError("OpenAI response did not include output text.")

    try:
        return json.loads(strip_code_fence(output_text))
    except json.JSONDecodeError as error:
        raise BackendError(f"OpenAI returned text that could not be parsed as JSON: {error.msg}")


def request_openai(request_body: dict[str, Any], schema_name: str) -> dict[str, Any]:
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
            return payload
        except urllib.error.HTTPError as error:
            message = openai_error_message(error)
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

    raise BackendError("OpenAI request failed before returning a response.", 504)


def openai_error_message(error: urllib.error.HTTPError) -> str:
    detail = error.read().decode("utf-8")
    try:
        return json.loads(detail).get("error", {}).get("message") or detail
    except json.JSONDecodeError:
        return detail


def extract_output_text(payload: dict[str, Any]) -> str:
    if isinstance(payload.get("output_text"), str):
        return payload["output_text"]

    parts: list[str] = []
    for item in payload.get("output", []):
        for content in item.get("content", []):
            if isinstance(content.get("text"), str):
                parts.append(content["text"])
            if isinstance(content.get("output_text"), str):
                parts.append(content["output_text"])
    return "\n".join(parts).strip()


def strip_code_fence(value: str) -> str:
    text = value.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def should_retry_openai_error(status_code: int, message: str, attempt: int) -> bool:
    if attempt >= OPENAI_MAX_ATTEMPTS:
        return False
    retryable_status = status_code in (408, 429, 500, 502, 503, 504)
    retryable_message = "upstream connect error" in message.lower() or "connection timed out" in message.lower()
    return retryable_status or retryable_message


def wait_before_retry(attempt: int, message: str) -> None:
    wait_time = min(2 * attempt, 6)
    print(f"OpenAI request failed transiently: {message}")
    print(f"Retrying in {wait_time}s")
    time.sleep(wait_time)
