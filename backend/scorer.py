from decimal import Decimal, ROUND_HALF_UP
from math import isfinite

from evidence_models import CategoryEvidence


ANSWER_VALUES = {"yes": 1.0, "partial": 0.5, "no": 0.0}


def score_out_of_ten(percent: float | None) -> int | None:
    if percent is None:
        return None
    if not isfinite(percent) or not 0 <= percent <= 100:
        raise ValueError("Performance percentage must be between 0 and 100")

    value = Decimal(str(percent)) / Decimal("10")
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def score_out_of_five(percent: float | None) -> int | None:
    if percent is None:
        return None
    if not isfinite(percent) or not 0 <= percent <= 100:
        raise ValueError("Performance percentage must be between 0 and 100")

    value = Decimal(str(percent)) / Decimal("20")
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _question_key(question: str) -> str:
    return " ".join(question.split()).casefold()


def score_category(
    evidence: CategoryEvidence,
    question_weights: list[float] | None = None,
    questions: list[str] | None = None,
) -> dict:
    answers = list(evidence.answers)
    if questions is not None:
        expected_keys = [_question_key(q) for q in questions]
        returned_keys = [_question_key(a.question) for a in answers]
        if len(set(expected_keys)) != len(expected_keys):
            raise ValueError(f"Duplicate rubric questions: {evidence.category}")
        if len(set(returned_keys)) != len(returned_keys):
            raise ValueError(f"Duplicate evidence answers: {evidence.category}")
        if set(expected_keys) != set(returned_keys):
            raise ValueError(
                f"Evidence questions do not match rubric: {evidence.category}"
            )
        by_question = dict(zip(returned_keys, answers))
        answers = [by_question[key] for key in expected_keys]

    weights = (
        list(question_weights)
        if question_weights is not None else [1.0] * len(answers)
    )
    if len(weights) != len(answers):
        raise ValueError(f"Question-weight count mismatch: {evidence.category}")
    if any(not isfinite(w) or w < 0 for w in weights):
        raise ValueError("Question weights must be finite and nonnegative")
    if weights and sum(weights) <= 0:
        raise ValueError("At least one question weight must be positive")

    rows = [(answer, weight) for answer, weight in zip(answers, weights)
            if weight > 0]
    applicable = [(answer, weight) for answer, weight in rows
                  if answer.answer != "not_applicable"]

    if rows and not applicable:
        return {"raw_score": None, "transparency_score": None,
                "status": "not_applicable"}

    known = [(answer, weight) for answer, weight in applicable
             if answer.answer in ANSWER_VALUES]
    applicable_weight = sum(weight for _, weight in applicable)
    known_weight = sum(weight for _, weight in known)

    coverage = (known_weight / applicable_weight * 100
                if applicable_weight else 0.0)
    performance = (
        sum(ANSWER_VALUES[answer.answer] * weight
            for answer, weight in known) / known_weight * 100
        if known_weight else None
    )

    return {
        "raw_score": performance,
        "transparency_score": round(coverage, 1),
        "status": "evaluated" if known_weight else "insufficient_evidence",
    }


def weighted_average(
    scores: dict[str, float | None],
    rubric: dict[str, float],
) -> float | None:
    included = {category: weight for category, weight in rubric.items()
                if weight > 0 and scores[category] is not None}
    total_weight = sum(Decimal(str(weight)) for weight in included.values())
    if total_weight == 0:
        return None
    weighted_sum = sum(
        Decimal(str(scores[category])) * Decimal(str(weight))
        for category, weight in included.items()
    )
    return float(weighted_sum / total_weight)


def score_environment(
    evidence_by_category: dict[str, CategoryEvidence],
    rubric: dict[str, float],
    question_weights_by_category: dict[str, list[float]] | None = None,
    questions_by_category: dict[str, list[str]] | None = None,
) -> dict:
    if any(not isfinite(w) or w < 0 for w in rubric.values()):
        raise ValueError("Rubric weights must be finite and nonnegative")
    if abs(sum(rubric.values()) - 1.0) > 0.001:
        raise ValueError("Rubric weights must add up to 1.0")
    if questions_by_category is not None and set(questions_by_category) != set(rubric):
        raise ValueError("Rubric categories and question categories must match")
    weight_map = question_weights_by_category or {}
    if set(weight_map) - set(rubric):
        raise ValueError("Question weights include an unknown category")

    category_percentages = {}
    category_transparency = {}
    category_status = {}
    for category in rubric:
        if category not in evidence_by_category:
            raise ValueError(f"Missing evidence for category: {category}")
        result = score_category(
            evidence_by_category[category],
            question_weights=weight_map.get(category),
            questions=(questions_by_category[category]
                       if questions_by_category is not None else None),
        )
        category_percentages[category] = result["raw_score"]
        category_transparency[category] = result["transparency_score"]
        category_status[category] = result["status"]

    performance = weighted_average(category_percentages, rubric)
    coverage = weighted_average(category_transparency, rubric)
    status = ("not_applicable" if coverage is None
              else "insufficient_evidence" if performance is None
              else "evaluated")
    return {
        "category_scores": {
            category: score_out_of_five(value)
            for category, value in category_percentages.items()
        },
        "category_transparency": category_transparency,
        "category_status": category_status,
        "raw_score": score_out_of_ten(performance),
        "final_score": score_out_of_ten(performance),
        "transparency_score": round(coverage, 1) if coverage is not None else None,
        "status": status,
    }










