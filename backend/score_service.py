from concurrent.futures import ThreadPoolExecutor, as_completed

from evidence_models import CategoryEvidence
from models import AnimalRubricType, ScoreItem, ScoreResponse, Source
from research.rubric_selector import infer_animal_rubric
from rubrics import (
    ENVIRONMENTAL_QUESTIONS,
    ENVIRONMENTAL_RUBRIC,
    NON_ANIMAL_PRODUCT_QUESTIONS,
    NON_ANIMAL_PRODUCT_RUBRIC,
    NON_ANIMAL_PRODUCT_QUESTION_WEIGHTS,
    ANIMAL_PRODUCT_QUESTIONS,
    ANIMAL_PRODUCT_RUBRIC,
    ANIMAL_PRODUCT_QUESTION_WEIGHTS,
    ETHICAL_LABOR_QUESTIONS,
    ETHICAL_LABOR_RUBRIC,
)
from scorer import score_environment


MAX_RESEARCH_WORKERS = 15

ANIMAL_RUBRIC_CONFIG = {
    "non_animal_products": (
        NON_ANIMAL_PRODUCT_QUESTIONS,
        NON_ANIMAL_PRODUCT_RUBRIC,
        NON_ANIMAL_PRODUCT_QUESTION_WEIGHTS,
    ),
    "animal_products": (
        ANIMAL_PRODUCT_QUESTIONS,
        ANIMAL_PRODUCT_RUBRIC,
        ANIMAL_PRODUCT_QUESTION_WEIGHTS,
    ),
}


def collect_sources(
    evidence_by_category: dict[str, CategoryEvidence],
) -> list[Source]:
    """Create one deduplicated top-level source list."""

    sources_by_url: dict[str, Source] = {}

    for evidence in evidence_by_category.values():
        for answer in evidence.answers:
            if answer.source_url is None:
                continue

            if answer.source_url not in sources_by_url:
                sources_by_url[answer.source_url] = Source(
                    title=answer.source_title or answer.source_url,
                    url=answer.source_url,
                    source_type=answer.source_type or "other",
                )

    return list(sources_by_url.values())


def research_and_analyze_category(
    company_name: str,
    category: str,
    questions: list[str],
) -> CategoryEvidence:

    from research.analyzer import analyze_category
    from research.web_researcher import research_company

    print(f"Researching {company_name}: {category}...")

    source_text = research_company(
        company_name=company_name,
        category=category,
        questions=questions,
    )

    print(
        f"\n--- RESEARCH REPORT: {company_name} / {category} ---\n"
        f"{source_text}\n"
        f"--- END REPORT ---\n",
        flush=True,
    )

    return analyze_category(
        company_name=company_name,
        category=category,
        questions=questions,
        source_text=source_text,
    )


def get_dimensions(animal_rubric_type: AnimalRubricType) -> dict:
    if animal_rubric_type not in ANIMAL_RUBRIC_CONFIG:
        raise ValueError(f"Unknown animal rubric type: {animal_rubric_type}")

    return {
        "sustainability": (
            ENVIRONMENTAL_QUESTIONS,
            ENVIRONMENTAL_RUBRIC,
            None,
        ),
        "animal_welfare": ANIMAL_RUBRIC_CONFIG[animal_rubric_type],
        "ethical_labor": (
            ETHICAL_LABOR_QUESTIONS,
            ETHICAL_LABOR_RUBRIC,
            None,
        ),
    }


def build_score_response(
    product_name: str,
    company_name: str,
    animal_rubric_type: AnimalRubricType,
    completed_evidence: dict[str, dict[str, CategoryEvidence]],
) -> ScoreResponse:

    dimensions = get_dimensions(animal_rubric_type)
    for dimension, (questions_by_category, _, _) in dimensions.items():
        for category in questions_by_category:
            if category not in completed_evidence.get(dimension, {}):
                raise ValueError(f"Missing evidence for {dimension}/{category}")

    score_items: dict[str, ScoreItem] = {}
    sources_by_url: dict[str, Source] = {}

    for dimension, (questions_by_category, rubric, question_weights) in dimensions.items():
        evidence_by_category = {
            category: completed_evidence[dimension][category]
            for category in questions_by_category
        }
        result = score_environment(
            evidence_by_category=evidence_by_category,
            rubric=rubric,
            question_weights_by_category=question_weights,
            questions_by_category=questions_by_category,
        )

        score_items[dimension] = ScoreItem(
            score=result["final_score"],
            raw_score=result["raw_score"],
            transparency_score=result["transparency_score"],
            breakdown=result["category_scores"],
            transparency_breakdown=result["category_transparency"],
            category_status=result["category_status"],
            evidence=evidence_by_category,
            status=result["status"],
            reason={
                "evaluated": (
                    "Performance calculated from known answers. "
                    "Evidence coverage is reported separately."
                ),
                "insufficient_evidence": (
                    "No known answers in the weighted categories; "
                    "performance cannot be calculated."
                ),
                "not_applicable": (
                    "All weighted categories were assessed as not applicable."
                ),
            }[result["status"]],
        )

        for source in collect_sources(evidence_by_category):
            sources_by_url.setdefault(source.url, source)

    return ScoreResponse(
        animal_rubric_type=animal_rubric_type,
        product_name=product_name,
        company_name=company_name,
        data_status="live_research",

        sustainability=score_items["sustainability"],

        animal_welfare=score_items["animal_welfare"],

        ethical_labor=score_items["ethical_labor"],

        summary=(
            f"Environmental, animal-welfare, and ethical-labor "
            f"scores for {company_name}, requested for "
            f"{product_name}, based on researched public evidence."
        ),

        sources=list(sources_by_url.values()),
    )


def get_score(
    product_name: str,
    company_name: str,
    animal_rubric_type: AnimalRubricType | None = None,
) -> ScoreResponse:
    if animal_rubric_type is None:
        print(f"Selecting animal rubric for {product_name}...", flush=True)
        animal_rubric_type = infer_animal_rubric(product_name, company_name)
        print(f"Selected animal rubric: {animal_rubric_type}", flush=True)

    dimensions = get_dimensions(animal_rubric_type)

    completed_evidence: dict[
        str, dict[str, CategoryEvidence]
    ] = {
        dimension: {}
        for dimension in dimensions
    }
    with ThreadPoolExecutor(
        max_workers=MAX_RESEARCH_WORKERS
    ) as executor:

        future_to_category = {}

        for dimension, (questions_by_category, _, _) in dimensions.items():
            for category, questions in questions_by_category.items():
                future = executor.submit(
                    research_and_analyze_category,
                    company_name,
                    category,
                    questions,
                )

                future_to_category[future] = (
                    dimension,
                    category,
                )

        for future in as_completed(future_to_category):
            dimension, category = future_to_category[future]

            try:
                completed_evidence[dimension][category] = (
                    future.result()
                )
                print(
                    f"Finished {company_name}: "
                    f"{dimension}/{category}"
                )

            except Exception as error:
                for pending_future in future_to_category:
                    pending_future.cancel()

                raise RuntimeError(
                    f"Failed while processing "
                    f"{dimension}/{category}"
                ) from error

    return build_score_response(
        product_name=product_name,
        company_name=company_name,
        animal_rubric_type=animal_rubric_type,
        completed_evidence=completed_evidence,
    )
