"""Private HTTP entry point for MIRU's durable research worker.

Deploy this as a SEPARATE Cloud Run service that requires authentication.
Grant invoker access only to the designated task and scheduler service accounts.
Cloud Run verifies their OIDC tokens before requests reach this application;
Cloud Tasks headers are not authentication. Never expose this worker publicly.

Importing the app does not construct clients or start research. Production
startup must use the same source/image as the API, with a 900-second Cloud Run
request timeout. Queue delivery and scheduled recovery are configured later.
"""

from __future__ import annotations

import logging
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from cloud_config import CloudRuntime, get_runtime
from job_store import JobBusyError
from job_worker import RetryableJobError
from task_queue import WORKER_TASK_PATH, dispatch_pending


logger = logging.getLogger(__name__)
RETRY_HEADERS = {"Retry-After": "30"}

app = FastAPI(
    title="MIRU private research worker",
    docs_url=None, redoc_url=None, openapi_url=None,
)


class ScoreStepRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    job_id: str = Field(strict=True, pattern=r"^[a-f0-9]{32}$")
    revision: int = Field(strict=True, ge=0, le=2**63 - 1)


class ScoreStepResponse(BaseModel):
    status: Literal["advanced", "completed", "failed", "ignored"]


class RecoveryResponse(BaseModel):
    enqueued: int = Field(ge=0)
    deferred: int = Field(ge=0)
    errors: int = Field(ge=0)


def _worker_runtime() -> CloudRuntime:
    try:
        return get_runtime()
    except Exception as error:
        logger.exception("Private worker runtime is unavailable")
        raise HTTPException(
            status_code=503, detail="Worker setup is unavailable. Delivery can be retried.",
            headers=RETRY_HEADERS,
        ) from error


@app.get("/health")
def health() -> dict[str, str]:
    """Process health only; this does not verify Google permissions or live AI."""
    return {"status": "ok"}


@app.post(WORKER_TASK_PATH, response_model=ScoreStepResponse)
def process_score_step(request: ScoreStepRequest,
                       runtime: CloudRuntime = Depends(_worker_runtime)) -> ScoreStepResponse:
    try:
        outcome = runtime.worker.process_step(request.job_id, request.revision)
        # A terminal failure is already saved for the phone: acknowledge delivery.
        # Stale deliveries are also safe to acknowledge without repeating work.
        return ScoreStepResponse(status=outcome)
    except (JobBusyError, RetryableJobError) as error:
        raise HTTPException(
            status_code=503, detail="This research step can be retried.",
            headers=RETRY_HEADERS,
        ) from error
    except Exception as error:
        logger.exception("Worker request failed for job %s revision %s", request.job_id, request.revision)
        raise HTTPException(
            status_code=503, detail="The worker is temporarily unavailable. Delivery can be retried.",
            headers=RETRY_HEADERS,
        ) from error


@app.post("/tasks/recover", response_model=RecoveryResponse)
def recover_pending_jobs(runtime: CloudRuntime = Depends(_worker_runtime)):
    """Periodic Cloud Scheduler calls recover jobs even without phone traffic."""
    try:
        counts = RecoveryResponse(**dispatch_pending(runtime.store, runtime.queue))
    except Exception as error:
        logger.exception("Scheduled dispatch recovery failed")
        raise HTTPException(
            status_code=503, detail="Dispatch recovery is temporarily unavailable.",
            headers=RETRY_HEADERS,
        ) from error
    if counts.errors:
        # Let the scheduler retry partial failures; successful reservations remain
        # protected by their dispatch watchdog or the worker's live lease.
        return JSONResponse(status_code=503, content=counts.model_dump(), headers=RETRY_HEADERS)
    return counts
