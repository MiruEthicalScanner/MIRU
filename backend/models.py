from pydantic import BaseModel, Field
from typing import Annotated, Literal
from evidence_models import CategoryEvidence


AnimalRubricType = Literal["non_animal_products", "animal_products"]
ScoreValue = Annotated[int, Field(ge=0, le=10)]
CategoryScoreValue = Annotated[int, Field(ge=0, le=5)]


class ScoreRequest(BaseModel):
    animal_rubric_type: AnimalRubricType | None = None
    product_name: str = Field(
        min_length=1,
        examples=["Nano Puff Jacket"],
    )
    company_name: str = Field(
        min_length=1,
        examples=["Patagonia"],
    )


class ScoreItem(BaseModel):
    score: ScoreValue | None
    raw_score: ScoreValue | None = None
    transparency_score: float | None = None

    breakdown: dict[str, CategoryScoreValue | None] = Field(
        default_factory=dict
    )

    transparency_breakdown: dict[str, float | None] = Field(
        default_factory=dict
    )
    category_status: dict[str, str] = Field(default_factory=dict)
    evidence: dict[str, CategoryEvidence] = Field(
        default_factory=dict
    )

    status: str
    reason: str


class Source(BaseModel):
    title: str
    url: str
    source_type: str


class ScoreResponse(BaseModel):
    animal_rubric_type: AnimalRubricType = "non_animal_products"
    product_name: str
    company_name: str
    data_status: str
    sustainability: ScoreItem
    animal_welfare: ScoreItem
    ethical_labor: ScoreItem
    summary: str
    sources: list[Source]

class ScoreJobStarted(BaseModel):
    job_id: str
    status: Literal["queued"]


class ScoreJobStatus(BaseModel):
    job_id: str
    status: Literal[
        "queued",
        "running",
        "completed",
        "failed",
    ]
    result: ScoreResponse | None = None
    error: str | None = None
