import os
from typing import List, Optional
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

CLIENT_API_KEY = os.getenv("CLIENT_API_KEY", "")

app = FastAPI()

def require_key(auth: Optional[str]):
    if not auth or not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Unauthorized")
    token = auth[len("Bearer "):]
    if token != CLIENT_API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")

@app.get("/healthz")
def healthz():
    return {"ok": True}

# ----- Models -----
class NotesRequest(BaseModel):
    transcript: str = ""
    lectureTitle: str = ""

class NotesResponse(BaseModel):
    title: str
    detailedNotes: str
    conciseSummary: str
    keyTakeaways: str
    vocabularyTerms: str
    importantConcepts: str

class FlashcardsRequest(BaseModel):
    transcript: str = ""
    notes: NotesResponse

class Flashcard(BaseModel):
    front: str
    back: str

class QuizQuestion(BaseModel):
    kind: str
    prompt: str
    options: List[str] = []
    correctAnswer: str
    explanation: str

class QuizResponse(BaseModel):
    title: str
    questions: List[QuizQuestion]

class StudyGuideRequest(BaseModel):
    transcript: str = ""
    notes: NotesResponse

class StudyGuideResponse(BaseModel):
    title: str
    examReview: str
    topicSummaries: str
    importantConcepts: str
    keyDefinitions: str

class AnswerRequest(BaseModel):
    question: str
    noteContext: str

class AnswerResponse(BaseModel):
    content: str
    sources: List[str]

# ----- Endpoints -----
@app.post("/notes", response_model=NotesResponse)
def notes(req: NotesRequest, authorization: Optional[str] = Header(None)):
    require_key(authorization)
    title = f"{req.lectureTitle} Notes" if req.lectureTitle else "Lecture Notes"
    detailed = (req.transcript or "")[:600] or "Add transcript to generate detailed notes."
    return NotesResponse(
        title=title,
        detailedNotes=detailed,
        conciseSummary="This lecture introduces the main ideas and relationships.",
        keyTakeaways="- Review the core definitions.\n- Connect each concept to an example.\n- Revisit unclear sections.",
        vocabularyTerms="Concept: A major idea from the lecture.\nEvidence: Details that support an answer.",
        importantConcepts="Core definitions, examples, applications"
    )

@app.post("/flashcards", response_model=List[Flashcard])
def flashcards(req: FlashcardsRequest, authorization: Optional[str] = Header(None)):
    require_key(authorization)
    base = (req.notes.importantConcepts or "the main concept").split(",")[0].strip()
    return [
        Flashcard(front=f"Explain {base or 'the main concept'}.", back="Define it, explain why it matters, add an example."),
        Flashcard(front="What are two key takeaways?", back="\n".join(req.notes.keyTakeaways.splitlines()[:2]) or "Review the summary and examples.")
    ]

@app.post("/quiz", response_model=QuizResponse)
def quiz(req: FlashcardsRequest, authorization: Optional[str] = Header(None)):
    require_key(authorization)
    focus = (req.notes.importantConcepts or "the lecture topic").split(",")[0].strip()
    return QuizResponse(
        title=f"{focus or 'Lecture'} Quiz",
        questions=[
            QuizQuestion(
                kind="multipleChoice",
                prompt="Which concept is most central to this lecture?",
                options=[focus or "Lecture topic", "Unrelated dates", "Formatting rules", "Attendance policy"],
                correctAnswer=focus or "Lecture topic",
                explanation=f"The notes identify {focus or 'the topic'} as a recurring concept."
            ),
            QuizQuestion(
                kind="trueFalse",
                prompt=f"The lecture connects {focus or 'the topic'} with supporting evidence.",
                options=["True", "False"],
                correctAnswer="True",
                explanation="The notes group these terms as related study concepts."
            ),
            QuizQuestion(
                kind="shortAnswer",
                prompt="Summarize the lecture's main takeaway in one sentence.",
                options=[],
                correctAnswer=req.notes.conciseSummary or "Summarize the main idea and a key relationship.",
                explanation="Short answers are checked against the note summary and details."
            ),
        ]
    )

@app.post("/study-guide", response_model=StudyGuideResponse)
def study_guide(req: StudyGuideRequest, authorization: Optional[str] = Header(None)):
    require_key(authorization)
    return StudyGuideResponse(
        title="Exam Review Sheet",
        examReview="Prioritize the summary, then test yourself on every key takeaway.",
        topicSummaries=req.notes.detailedNotes or "Add transcript notes to build topic summaries.",
        importantConcepts=req.notes.importantConcepts or "Core concepts",
        keyDefinitions=req.notes.vocabularyTerms or "Key terms appear here"
    )

@app.post("/answer", response_model=AnswerResponse)
def answer(req: AnswerRequest, authorization: Optional[str] = Header(None)):
    require_key(authorization)
    if not (req.noteContext or "").strip():
        return AnswerResponse(content="I do not have enough note context to answer that yet.", sources=[])
    # naive “evidence” snippet
    line = next((l for l in req.noteContext.splitlines() if len(l.strip()) > 24), "")
    snippet = line[:160] if line else "review the summary and key takeaways."
    return AnswerResponse(content=f"Based on your notes: {snippet}", sources=[snippet] if line else ["Lecture notes"])
