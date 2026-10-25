from pydantic import BaseModel
from typing import Literal


class EvidenceAnswer(BaseModel):
    question: str
    answer: Literal[
        "yes",
        "partial",
        "no",
        "unknown",
        "not_applicable"
    ]

    explanation: str
    source_title: str | None = None
    source_url: str | None = None

    source_type: Literal[
        "government",
        "certification",
        "ngo",
        "news",
        "company",
        "other",
    ] | None = None

class CategoryEvidence(BaseModel):
    category: str
    answers: list[EvidenceAnswer]
    summary: str = ""