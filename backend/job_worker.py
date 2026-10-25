from __future__ import annotations

import logging
import os
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Callable

from evidence_models import CategoryEvidence
from job_store import JobStore, LeaseLostError
from research.rubric_selector import RubricSelectionError
from score_service import build_score_response, get_dimensions
from scorer import score_category
from task_queue import TaskQueue, WORKER_LEASE_SECONDS, dispatch_job


logger = logging.getLogger(__name__)
MAX_STEP_ATTEMPTS = 3
DEFAULT_RESEARCH_WORKERS = 18
RUBRIC_CHECKPOINT = "selection:animal_rubric"
RETRY_MESSAGE = "Research was interrupted repeatedly. Please try again."


class RetryableJobError(Exception):
    """The private HTTP handler must return a retryable, non-2xx response."""


class _ProductDetailsRequired(Exception):
    """Only a known, safe classification explanation may reach the phone."""


class _OperationFailure(Exception):
    def __init__(self, checkpoint_key: str, *, exhausted: bool):
        super().__init__("A category operation needs another attempt.")
        self.checkpoint_key = checkpoint_key
        self.exhausted = exhausted


class _BatchFailure(Exception):
    def __init__(self, *, exhausted: bool):
        super().__init__("Some category operations did not finish.")
        self.exhausted = exhausted


@dataclass(frozen=True)
class _Operation:
    dimension: str
    category: str
    questions: list[str]
    question_weights: dict | None
    report: str | None = None

    @property
    def key(self) -> str:
        kind = "report" if self.report is None else "evidence"
        return f"{kind}:{self.dimension}:{self.category}"


def _worker_count(value: int | None) -> int:
    if value is None:
        setting = os.getenv("MAX_RESEARCH_WORKERS", str(DEFAULT_RESEARCH_WORKERS))
        if not re.fullmatch(r"[0-9]{1,2}", setting):
            raise ValueError("MAX_RESEARCH_WORKERS must be a whole number from 1 to 18.")
        value = int(setting)
    if isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= 18:
        raise ValueError("MAX_RESEARCH_WORKERS must be a whole number from 1 to 18.")
    return value


def _select_rubric(product_name: str, company_name: str) -> str:
    from research.rubric_selector import infer_animal_rubric
    return infer_animal_rubric(product_name, company_name)


def _research(company_name: str, category: str, questions: list[str]) -> str:
    from research.web_researcher import research_company
    return research_company(company_name, category, questions)


def _analyze(company_name: str, category: str, questions: list[str],
             source_text: str) -> CategoryEvidence:
    from research.analyzer import analyze_category
    return analyze_category(company_name, category, questions, source_text)


class JobWorker:
    """Run classification, parallel category operations, or final assembly.

    The caller supplies configured storage and a queue. Injected research
    functions allow offline checks. Default AI functions are imported lazily;
    their HTTP timeouts are configured in the research modules. Each request
    runs at most max_workers operations, with one AI call per operation, then
    joins every thread before replying or releasing its lease. Reports and
    evidence are saved independently as they finish, not only at batch end.

    For the initial deployment use one concurrent Cloud Tasks delivery. With
    18 category workers, three concurrent deliveries could start 54 AI calls.
    """

    def __init__(self, store: JobStore, queue: TaskQueue, *,
                 selector: Callable | None = None,
                 researcher: Callable | None = None,
                 analyzer: Callable | None = None,
                 max_workers: int | None = None):
        self.store = store
        self.queue = queue
        self.selector = selector if selector is not None else _select_rubric
        self.researcher = researcher if researcher is not None else _research
        self.analyzer = analyzer if analyzer is not None else _analyze
        self.max_workers = _worker_count(max_workers)

    def process_step(self, job_id: str, revision: int) -> str:
        """Return advanced/completed/failed/ignored, or raise for delivery retry.

        JobBusyError from claim_step must also produce a retryable HTTP status.
        Missing, completed, or stale deliveries are safe to acknowledge.
        """
        if not isinstance(job_id, str) or not re.fullmatch(r"[a-f0-9]{32}", job_id):
            raise ValueError("Invalid worker job ID.")
        if isinstance(revision, bool) or not isinstance(revision, int) or revision < 0:
            raise ValueError("Invalid worker revision.")

        owned = self.store.claim_step(
            job_id, revision, lease_seconds=WORKER_LEASE_SECONDS,
            max_attempts=MAX_STEP_ATTEMPTS,
        )
        if owned is None:
            self._dispatch_next(job_id)
            return "ignored"

        token = owned["lease_token"]
        try:
            outcome = self._advance(job_id, token, owned["request"])
        except _ProductDetailsRequired as error:
            try:
                self.store.fail_job(job_id, token, str(error))
                outcome = "failed"
            except LeaseLostError:
                outcome = "ignored"
        except _BatchFailure as error:
            try:
                if error.exhausted:
                    self.store.fail_job(job_id, token, RETRY_MESSAGE)
                    outcome = "failed"
                else:
                    # Each report/analysis has its own persisted attempt count.
                    # Failures in different categories must not consume each
                    # other's allowance. The job-level count still limits
                    # crashes, classification, and infrastructure failures.
                    self.store.retry_step(job_id, token, reset_attempts=True)
                    raise RetryableJobError("Unfinished categories will be retried.") from error
            except LeaseLostError:
                outcome = "ignored"
        except LeaseLostError:
            # A newer lease or an acknowledged checkpoint already owns progress.
            outcome = "ignored"
        except Exception as error:
            logger.exception("Research step failed for job %s revision %s", job_id, revision)
            try:
                if owned["step_attempts"] >= MAX_STEP_ATTEMPTS:
                    self.store.fail_job(job_id, token, RETRY_MESSAGE)
                    outcome = "failed"
                else:
                    self.store.retry_step(job_id, token)
                    raise RetryableJobError("The research step will be retried.") from error
            except LeaseLostError:
                # A write may have committed even if its RPC response was lost.
                outcome = "ignored"

        self._dispatch_next(job_id)
        return outcome

    def _advance(self, job_id: str, token: str, request: dict) -> str:
        selected = self.store.get_checkpoint(job_id, RUBRIC_CHECKPOINT)
        if selected is None:
            choice = request.get("animal_rubric_type")
            if choice is None:
                try:
                    choice = self.selector(request["product_name"], request["company_name"])
                except RubricSelectionError as error:
                    if error.__cause__ is not None:
                        # The existing selector wraps temporary provider failures.
                        raise
                    raise _ProductDetailsRequired(str(error)) from error
            get_dimensions(choice)  # Reject unexpected classifier values.
            self.store.save_checkpoint(job_id, token, RUBRIC_CHECKPOINT,
                                       {"animal_rubric_type": choice})
            return "advanced"

        choice = selected["animal_rubric_type"]
        dimensions = get_dimensions(choice)
        completed = {dimension: {} for dimension in dimensions}
        pending = []
        for dimension, (questions_by_category, _, question_weights) in dimensions.items():
            for category, questions in questions_by_category.items():
                evidence_key = f"evidence:{dimension}:{category}"
                evidence_data = self.store.get_checkpoint(job_id, evidence_key)
                if evidence_data is not None:
                    evidence = self._validated_evidence(evidence_data, category, questions,
                                                        question_weights)
                    completed[dimension][category] = evidence
                    continue

                report_key = f"report:{dimension}:{category}"
                report = self.store.get_checkpoint(job_id, report_key)
                if report is None:
                    pending.append(_Operation(dimension, category, questions, question_weights))
                else:
                    source_text = report["source_text"]
                    if not isinstance(source_text, str) or not source_text.strip():
                        raise ValueError("The saved research report is invalid.")
                    pending.append(_Operation(dimension, category, questions,
                                              question_weights, source_text))

        if pending:
            self._run_batch(job_id, token, request["company_name"], pending[:self.max_workers])
            self.store.advance_step(job_id, token)
            return "advanced"

        result = build_score_response(
            product_name=request["product_name"], company_name=request["company_name"],
            animal_rubric_type=choice, completed_evidence=completed,
        )
        self.store.complete_job(job_id, token, result.model_dump(mode="json"))
        return "completed"

    def _run_batch(self, job_id: str, token: str, company: str,
                   operations: list[_Operation]):
        errors = []
        # Never submit more than one wave: 21 categories with 18 threads must
        # not turn into two long research waves inside one 900-second request.
        # Remaining categories get another durable Cloud Tasks delivery.
        with ThreadPoolExecutor(max_workers=self.max_workers,
                                thread_name_prefix="miru-category") as executor:
            futures = [executor.submit(self._run_operation, job_id, token, company, operation)
                       for operation in operations]
            for future in as_completed(futures):
                try:
                    future.result()
                except Exception as error:
                    errors.append(error)

        # All category threads have stopped before we release or replace the
        # lease. Give fencing precedence over ordinary provider failures.
        for error in errors:
            if isinstance(error, LeaseLostError):
                raise error
        for error in errors:
            if not isinstance(error, _OperationFailure):
                raise error
        failures = []
        for error in errors:
            # A Firestore write can commit and then lose its RPC reply. The
            # durable checkpoint proves completion even on the last attempt.
            if self.store.get_checkpoint(job_id, error.checkpoint_key) is None:
                failures.append(error)
        if failures:
            raise _BatchFailure(exhausted=any(error.exhausted for error in failures))

    def _run_operation(self, job_id: str, token: str, company: str,
                       operation: _Operation):
        attempts_key = "attempts:" + operation.key
        saved = self.store.get_checkpoint(job_id, attempts_key)
        attempts = saved["attempts"] if saved is not None else 0
        if isinstance(attempts, bool) or not isinstance(attempts, int) or not 0 <= attempts <= MAX_STEP_ATTEMPTS:
            raise ValueError("The saved category attempt count is invalid.")
        if attempts >= MAX_STEP_ATTEMPTS:
            raise _OperationFailure(operation.key, exhausted=True)

        # Persist attempts before the external call, including interrupted
        # calls whose response never reached the worker. This bounds retries.
        attempts += 1
        self.store.save_progress(job_id, token, attempts_key, {"attempts": attempts})
        try:
            if operation.report is None:
                source_text = self.researcher(company, operation.category, operation.questions)
                if not isinstance(source_text, str) or not source_text.strip():
                    raise ValueError("Research did not return a usable report.")
                data = {"source_text": source_text}
            else:
                evidence = self.analyzer(company, operation.category,
                                         operation.questions, operation.report)
                evidence = self._validated_evidence(
                    evidence, operation.category, operation.questions,
                    operation.question_weights,
                )
                data = evidence.model_dump(mode="json")
            self.store.save_progress(job_id, token, operation.key, data)
        except LeaseLostError:
            raise
        except Exception as error:
            logger.warning("Category operation failed for job %s category %s operation %s: %s",
                           job_id, operation.category, operation.key.split(":", 1)[0],
                           type(error).__name__)
            raise _OperationFailure(operation.key,
                                    exhausted=attempts >= MAX_STEP_ATTEMPTS) from error

    @staticmethod
    def _validated_evidence(data, category, questions, question_weights):
        evidence = CategoryEvidence.model_validate(data)
        if evidence.category != category:
            raise ValueError("Evidence category does not match the saved processing step.")
        # Check the original question text and weights before saving progress.
        # Numeric performance still comes from the unchanged scorer at assembly.
        score_category(evidence, questions=questions,
                       question_weights=(question_weights or {}).get(category))
        return evidence

    def _dispatch_next(self, job_id: str):
        try:
            dispatch_job(self.store, self.queue, job_id)
        except Exception:
            # The checkpoint/queued state is already durable. A scheduled recovery
            # pass must resend it even when no phone is connected.
            logger.exception("Next-step dispatch deferred for job %s", job_id)
