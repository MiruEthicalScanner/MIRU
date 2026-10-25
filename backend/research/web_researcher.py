"""Category web research with explicit HTTP timeouts and durable-worker retries."""

from dotenv import load_dotenv
from openai import OpenAI, Timeout

# Use explicit HTTP timeouts; allow most of the wait for server-side research.
# Retries belong to the durable worker, which preserves completed steps.
RESEARCH_TIMEOUT_SECONDS = 600.0


def research_company(
    company_name: str,
    category: str,
    questions: list[str] | None = None,
) -> str:
    """Research one category using the original prompt and model.

    Construct and close the client per call. Importing this module never reads
    credentials or creates a connection. Timeouts and provider errors propagate
    to the durable worker, which decides whether the step should be retried.
    """
    load_dotenv()

    questions_text = "\n".join(
        f"- {question}" for question in (questions or [])
    )

    with OpenAI(
        timeout=Timeout(RESEARCH_TIMEOUT_SECONDS, connect=10.0, write=30.0, pool=10.0),
        max_retries=0,
    ) as client:
        response = client.responses.create(
            model="gpt-5.6-luna",
            tools=[{"type": "web_search"}],
            include=["web_search_call.action.sources"],
            input=f"""
Research {company_name} for evidence about {category}.

Questions to investigate:
{questions_text}

MANDATORY SOURCE CHECKS

Before completing this research report, attempt to check all
three organizations below for information about {company_name}:

1. KnowTheChain
   - https://knowthechain.org/
   - https://www.business-humanrights.org/en/from-us/knowthechain/
   - Search company scorecards, benchmark findings, and reports.
   - Look for evidence about forced labor, recruitment,
     worker voice, supplier monitoring, and remedy.

2. PETA
   - https://www.peta.org/
   - https://crueltyfree.peta.org/
   - https://petaapprovedvegan.peta.org/
   - Look for relevant animal-testing listings, vegan approvals,
     investigations, and documented animal-welfare concerns.

3. Fair Labor Association
   - https://www.fairlabor.org/
   - Look for company accreditation reports, factory and farm
     assessments, corrective-action plans, and progress updates.

Search using the company's name and relevant brand names.
Keep evidence about a brand, parent company, product, or supplier
clearly distinguished.

For EACH organization, include a source-check summary stating:
- Relevant company evidence found;
- No company match found;
- Company information found, but none relevant to this category; or
- Unable to access or verify the source.

Include the actual page URLs and available publication dates.
Do not claim to have checked a source unless you actually searched
or retrieved it.

Use findings only for questions they directly support.
Do not copy another organization's overall score into this rubric.
Absence from a list does not prove harmful practices.
Accreditation or approval does not establish compliance with
every question or across every product and supplier.

Continue researching company reports, government findings,
and other credible independent sources to fill evidence gaps.

Find information from reliable sources such as:
- the company's reports and website
- government sources
- recognized certification registries
- reputable NGOs
- reputable news organizations

Find concrete facts, policies, metrics, targets, audits,
certifications, and documented violations.

For animal-related questions:
- Investigate products, ingredients, suppliers, and third parties.
- Check the scope of policies and any market-access exceptions.
- Distinguish company-wide claims from individual product claims.
- Verify certification scope and current status where possible.
- Find evidence establishing whether particular animal materials
  are used, so inapplicable questions can be identified.
- Do not treat missing evidence as proof of good or bad practices.
- Do not treat absence of reported controversy as proof of compliance.

For ethical-labor questions:
- Investigate direct employees, agency and contract workers,
  and relevant supply-chain workers.
- Identify the worker groups, locations, and reporting dates.
- Seek evidence of actual practice, not only company policies.
- Look for worker testimony, union reports, government findings,
  credible NGO investigations, wage data, and monitoring results.
- Distinguish allegations from substantiated violations.
- Investigate remedies and whether their completion was verified.
- Do not assume no complaints means no violations.
- Identify the exact scope of certifications and audits.

Return an evidence report addressing each question.
Include source titles and URLs for important claims.
Clearly identify information you could not establish.
Do not make assumptions.
"""
        )

    if response.status != "completed":
        raise ValueError("The research request did not complete. Please try again.")
    if not isinstance(response.output_text, str) or not response.output_text.strip():
        raise ValueError("The research request returned no usable report.")
    return response.output_text
