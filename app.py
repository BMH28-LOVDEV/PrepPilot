import os
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse

app = FastAPI()

# Accept either APP_API_KEY or CLIENT_API_KEY to match your Render env var name
APP_API_KEY = (os.getenv("APP_API_KEY") or os.getenv("CLIENT_API_KEY") or "").strip()

def authorized(req: Request) -> bool:
    if not APP_API_KEY:
        # Allow all if no key is set (useful for quick smoke tests)
        return True
    auth = req.headers.get("authorization", "")
    xkey = req.headers.get("x-api-key", "")
    bearer = ""
    if auth.lower().startswith("bearer "):
        bearer = auth[len("Bearer "):].strip()
    return (bearer and bearer == APP_API_KEY) or (xkey and xkey == APP_API_KEY)

def require_auth(req: Request):
    if not authorized(req):
        raise HTTPException(status_code=401, detail="unauthorized")

@app.get("/healthz")
async def healthz():
    return {"status": "ok"}

# Notes
@app.post("/api/generate-notes")
@app.post("/api/generate_notes")
async def generate_notes(req: Request):
    require_auth(req)
    data = await req.json()
    transcript = data.get("transcript", "")
    lecture_title = data.get("lecture_title") or data.get("lectureTitle") or "Untitled"
    return JSONResponse({
        "title": lecture_title,
        "detailed_notes": f"Detailed notes for: {lecture_title}\\n\\n{transcript[:500]}...",
        "concise_summary": "A concise summary goes here.",
        "key_takeaways": "1) Key idea one\\n2) Key idea two",
        "vocabulary_terms": "Term A: definition\\nTerm B: definition",
        "important_concepts": "Concept 1, Concept 2"
    })

# Flashcards
@app.post("/api/generate-flashcards")
@app.post("/api/generate_flashcards")
async def generate_flashcards(req: Request):
    require_auth(req)
    return JSONResponse([
        {"front": "What is Topic A?", "back": "Topic A is ..."},
        {"front": "Define Term B", "back": "Term B means ..."}
    ])

# Quiz
@app.post("/api/generate-quiz")
@app.post("/api/generate_quiz")
async def generate_quiz(req: Request):
    require_auth(req)
    return JSONResponse({
        "title": "Quick Check",
        "questions": [
            {
                "kind": "multiple_choice",
                "prompt": "Which is correct?",
                "options": ["A", "B", "C"],
                "correct_answer": "A",
                "explanation": "Because A is correct in this stub."
            },
            {
                "kind": "true_false",
                "prompt": "Statement X is true.",
                "options": [],
                "correct_answer": "true",
                "explanation": "Stub explanation."
            }
        ]
    })

# Study Guide
@app.post("/api/generate-study-guide")
@app.post("/api/generate_study_guide")
async def generate_study_guide(req: Request):
    require_auth(req)
    return JSONResponse({
        "title": "Study Guide",
        "exam_review": "Review Section",
        "topic_summaries": "Topic 1 summary; Topic 2 summary",
        "important_concepts": "Concept A, Concept B",
        "key_definitions": "Term X: ..., Term Y: ..."
    })

# Answer
@app.post("/api/answer")
async def answer(req: Request):
    require_auth(req)
    data = await req.json()
    question = data.get("question") or data.get("question_text") or ""
    return JSONResponse({
        "content": f"Stub answer for: {question}",
        "sources": ["Notes Context"]
    })
