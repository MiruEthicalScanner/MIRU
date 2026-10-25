from collections import Counter
from typing import Literal

from dotenv import load_dotenv
from openai import OpenAI, Timeout
from pydantic import BaseModel, create_model

from evidence_models import CategoryEvidence, EvidenceAnswer
ANALYSIS_TIMEOUT_SECONDS = 180.0


class RubricAnswer(BaseModel):
    answer: Literal[
        "yes",
        "partial",
        "no",
        "unknown",
        "not_applicable",
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


def _summary_or_fallback(
    summary: str,
    answers: list[EvidenceAnswer],
) -> str:
    summary = summary.strip()

    if summary:
        return summary

    counts = Counter(answer.answer for answer in answers)

    if answers and counts["unknown"] == len(answers):
        return (
            "The supplied evidence is insufficient to assess "
            "this category. Missing information does not establish "
            "that the company fails the criteria."
        )

    if answers and counts["not_applicable"] == len(answers):
        return (
            "The supplied evidence indicates that this category "
            "does not apply to the assessed operations."
        )

    return (
        f"The question-level findings include "
        f"{counts['yes']} supported criteria, "
        f"{counts['partial']} partly supported criteria, "
        f"and {counts['no']} unmet criteria. "
        f"There are {counts['unknown']} unknown answers and "
        f"{counts['not_applicable']} answers marked not applicable; "
        "review the individual explanations for their scope "
        "and supporting evidence."
    )


def analyze_category(
    company_name: str,
    category: str,
    questions: list[str],
    source_text: str,
) -> CategoryEvidence:
    """Extract evidence with the original question IDs, prompt, and model.

    Create and close a client only when analysis is requested. Request failures
    propagate so the durable worker can retry analysis using the saved report.
    """
    if not questions:
        raise ValueError(
            f"No rubric questions supplied for {category}."
        )

    # Each question gets its own required response field.
    # The AI does not generate the question wording.
    answer_model = create_model(
        "CategoryAnswers",
        summary=(str, ...),
        **{
            f"q{i}": (RubricAnswer, ...)
            for i in range(len(questions))
        },
    )

    questions_text = "\n".join(
        f"q{i}: {question}"
        for i, question in enumerate(questions)
    )

    load_dotenv()
    with OpenAI(
        timeout=Timeout(ANALYSIS_TIMEOUT_SECONDS, connect=10.0, write=30.0, pool=10.0),
        max_retries=0,
    ) as client:
        response = client.responses.parse(
            model="gpt-5-mini",

            instructions=(
                "You are an evidence extraction system. "
                "Use ONLY the supplied source text. "

                "In the summary field, give a category-level explanation "
                "in 1 to 3 short sentences. Summarize the key supported "
                "findings, concerns, and important gaps across this "
                "category's answers. "

                "Make the summary consistent with the question-level answers. "
                "Use only facts supported by the supplied source text, "
                "keeping the same species, worker groups, locations, dates, "
                "and sourcing scope as the underlying evidence. "
                "Distinguish published policies from verified implementation. "

                "If all answers are unknown, explain the evidence gap "
                "without implying poor performance. If all are "
                "not_applicable, explain why the category does not apply. "

                "Do not invent scores, percentages, facts, or citations. "
                "Numeric scores are calculated separately by the application. "
                "Do not repeat every question or give an overall company verdict. "

                "Answer every supplied question under its matching "
                "field ID: q0, q1, q2, and so on. "
                "Each ID must answer only its own question. "
                "Do not add question text or category fields "
                "to the response. "

                "Use 'yes' only when the source directly provides "
                "evidence that the answer to the question is yes. "

                "Use 'partial' only when the source directly supports "
                "part, but not all, of what the question asks. "

                "Use 'no' ONLY when the source explicitly states "
                "or clearly demonstrates that the company does "
                "not do the thing being asked about. "

                "Use 'unknown' when the source does not mention "
                "the topic, does not provide enough information, "
                "says that information is unavailable, or merely "
                "fails to report something. "

                "Use 'not_applicable' ONLY when the supplied evidence "
                "establishes that the question does not apply "
                "to this company. "
                "For example, a down-specific welfare question "
                "does not apply when evidence confirms that "
                "the company uses no down. "
                "Explain why it does not apply and cite "
                "the supporting source. "

                "Missing information is 'unknown', never "
                "'not_applicable'. "
                "A company failing to follow a practice is 'no', "
                "not 'not_applicable'. "
                "Do not mark a general animal-free question as "
                "not_applicable just because the company uses "
                "no animal materials; that is 'yes'. "

                "For animal-product questions, assess relevant "
                "owned facilities and supply-chain farms, "
                "transporters, and slaughter facilities. "
                "Identify the species and sourcing scope "
                "covered by evidence. "
                "Do not assume a company policy proves actual "
                "animal treatment. "

                "For animal-material replacement targets "
                "and progress, use 'not_applicable' when evidence "
                "confirms the company's entire product range "
                "is already free of animal-derived materials. "

                "If no relevant painful procedures occur, "
                "their pain-relief question may be "
                "'not_applicable'; avoiding unnecessary "
                "procedures can still be 'yes'. "

                "For dairy and eggs, assess relevant animal "
                "transport and end-of-life slaughter in their "
                "sourcing chains; do not mark these questions "
                "inapplicable merely because milk or eggs "
                "are the products sold. "

                "For ethical-labor questions, assess direct "
                "employees, agency and contract workers, "
                "and relevant supply-chain workers. "
                "Identify the worker groups, locations, "
                "and dates covered by the evidence "
                "in each explanation. "

                "A policy proves a commitment, not implementation. "
                "Questions asking about actual practice require "
                "evidence such as worker testimony, monitoring "
                "findings, pay data, or credible investigations. "

                "Use 'partial' when evidence demonstrates "
                "incomplete implementation or coverage limited "
                "to some relevant groups. "
                "Do not assume evidence about headquarters "
                "employees also applies to supplier workers. "

                "Absence of discovered complaints is not proof "
                "of good working conditions. "
                "Distinguish allegations from substantiated "
                "findings and verified remedies. "

                "For remedy questions, use 'not_applicable' "
                "only when evidence establishes that no relevant "
                "cases required remedy within the assessed scope. "
                "Otherwise, missing information is 'unknown'. "

                "Certification is supporting evidence only "
                "within its verified worker, location, "
                "and subject coverage. "

                "IMPORTANT: absence of information is NOT 'no'. "
                "For example, 'the report does not mention "
                "independent verification' must be classified "
                "as 'unknown', not 'no'. "

                "Every question is phrased so that 'yes' "
                "is positive and 'no' is negative. "
                "Do not interpret a lack of reported controversy "
                "as 'yes'; use 'unknown' unless the supplied "
                "evidence supports the conclusion. "

                "Do not guess and do not use outside knowledge."
            ),

            input=f"""
Company: {company_name}
Category: {category}

Questions:
{questions_text}

SOURCE TEXT:
{source_text}
""",

            text_format=answer_model,
        )

    if response.status != "completed":
        raise ValueError("The evidence analysis did not complete. Please try again.")
    if response.output_parsed is None:
        raise ValueError(
            "The AI did not return usable evidence."
        )

    parsed = response.output_parsed

    answers = [
        EvidenceAnswer(
            question=question,
            **getattr(parsed, f"q{i}").model_dump(),
        )
        for i, question in enumerate(questions)
    ]

    return CategoryEvidence(
        category=category,
        answers=answers,
        summary=_summary_or_fallback(parsed.summary, answers),
    )