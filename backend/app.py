from __future__ import annotations

import logging
import os
import re
from threading import Lock
from typing import Any
from uuid import uuid4

from fastapi import BackgroundTasks, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from cloud_config import CloudRuntime, get_runtime
from job_store import AdmissionError
from models import (
    AnimalRubricType, ScoreJobStarted, ScoreJobStatus,
    ScoreRequest, ScoreResponse,
)
from research.rubric_selector import RubricSelectionError
from score_service import get_score
from task_queue import dispatch_job


logger = logging.getLogger(__name__)
app = FastAPI(
    title="Ethical Scoring API",
    description="Scores products and companies using published evidence.",
    version="0.3.0",
)
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_credentials=False,
    allow_methods=["*"], allow_headers=["*"],
)
_jobs: dict[str, dict[str, Any]] = {}
_jobs_lock = Lock()


def _cloud_mode() -> bool:
    mode = os.getenv("MIRU_BACKEND_MODE", "").strip().lower()
    if mode not in ("", "local", "cloud"):
        raise HTTPException(status_code=503, detail="The server's backend mode is not configured correctly.")
    if os.getenv("K_SERVICE"):
        if mode == "local":
            raise HTTPException(status_code=503, detail="The hosted API requires durable job storage.")
        return True
    return mode == "cloud"


def _hosted_runtime() -> CloudRuntime:
    try:
        return get_runtime()
    except Exception as error:
        logger.exception("Hosted API runtime is unavailable")
        raise HTTPException(status_code=503, detail="The scoring service is temporarily unavailable.",
                            headers={"Retry-After": "30"}) from error


def _validated_request(request: ScoreRequest) -> ScoreRequest:
    payload = request.model_dump()
    for field in ("product_name", "company_name"):
        value = payload[field].strip()
        if not 1 <= len(value) <= 500:
            raise HTTPException(status_code=422,
                                detail=f"{field} must contain between 1 and 500 characters.")
        payload[field] = value
    return ScoreRequest(**payload)


def _update_job(job_id: str, **changes: Any):
    with _jobs_lock:
        _jobs[job_id].update(changes)


def _run_score_job(job_id: str, product_name: str, company_name: str,
                   animal_rubric_type: AnimalRubricType | None = None):
    """Existing local-only background scoring; never called on the hosted path."""
    _update_job(job_id, status="running")
    try:
        result = get_score(product_name=product_name, company_name=company_name,
                           animal_rubric_type=animal_rubric_type)
        _update_job(job_id, status="completed", result=result)
    except RubricSelectionError as error:
        logger.info("Local job %s needs product details: %s", job_id, error)
        _update_job(job_id, status="failed", error=str(error))
    except Exception:
        logger.exception("Local scoring job %s failed", job_id)
        _update_job(job_id, status="failed", error="Scoring failed. Check the backend terminal for details.")


@app.get("/health")
def health() -> dict[str, str]:
    """Process health; live Google/AI permissions are checked during deployment."""
    return {"status": "ok"}


@app.post("/score", response_model=ScoreResponse)
def score_product(request: ScoreRequest) -> ScoreResponse:
    if _cloud_mode():

        raise HTTPException(status_code=405, detail="Use POST /score-jobs and poll its job ID.")
    request = _validated_request(request)
    try:
        return get_score(product_name=request.product_name, company_name=request.company_name,
                         animal_rubric_type=request.animal_rubric_type)
    except RubricSelectionError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    except Exception as error:
        logger.exception("Direct local scoring failed")
        raise HTTPException(status_code=503, detail="Scoring is temporarily unavailable.") from error


@app.post("/score-jobs", response_model=ScoreJobStarted,
          status_code=status.HTTP_202_ACCEPTED)
def start_score_job(request: ScoreRequest, background_tasks: BackgroundTasks) -> ScoreJobStarted:
    request = _validated_request(request)
    if _cloud_mode():
        runtime = _hosted_runtime()
        try:
            job_id = runtime.store.create_job(request.model_dump(mode="json"))
        except AdmissionError as error:
            raise HTTPException(status_code=429, detail=str(error),
                                headers={"Retry-After": "60"}) from error
        except Exception as error:
            logger.exception("Hosted job could not be saved")
            raise HTTPException(status_code=503, detail="The job could not be confirmed. Please try again.",
                                headers={"Retry-After": "30"}) from error
        try:
            dispatch_job(runtime.store, runtime.queue, job_id)
        except Exception:

            logger.exception("Initial dispatch deferred for saved job %s", job_id)

        return ScoreJobStarted(job_id=job_id, status="queued")

    job_id = uuid4().hex
    with _jobs_lock:
        _jobs[job_id] = {"status": "queued", "result": None, "error": None}
    background_tasks.add_task(_run_score_job, job_id, request.product_name,
                              request.company_name, request.animal_rubric_type)
    return ScoreJobStarted(job_id=job_id, status="queued")


@app.get("/score-jobs/{job_id}", response_model=ScoreJobStatus)
def get_score_job(job_id: str) -> ScoreJobStatus:
    if not re.fullmatch(r"[a-f0-9]{32}", job_id):
        raise HTTPException(status_code=404, detail="Scoring job not found.")
    if _cloud_mode():
        runtime = _hosted_runtime()
        try:
            saved = runtime.store.get_job(job_id)
            if saved is not None:

                return ScoreJobStatus(**saved)
        except Exception as error:
            logger.exception("Hosted job status unavailable for job %s", job_id)
            raise HTTPException(status_code=503, detail="Job status is temporarily unavailable. Try again.",
                                headers={"Retry-After": "30"}) from error
    else:
        with _jobs_lock:
            saved = _jobs.get(job_id)
            saved = dict(saved) if saved is not None else None
        if saved is not None:
            return ScoreJobStatus(job_id=job_id, **saved)
    raise HTTPException(status_code=404, detail="Scoring job not found.")
