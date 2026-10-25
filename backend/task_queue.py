"""Send MIRU jobs to Cloud Tasks and recover missed dispatches.

Importing this file does not contact Google. Cloud configuration and credentials
are needed only when constructing a TaskQueue for the API or private worker.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import logging
import os
import re
from typing import TYPE_CHECKING, Any
from urllib.parse import urlsplit

from google.api_core.exceptions import AlreadyExists
from google.cloud import tasks_v2
from google.protobuf.duration_pb2 import Duration

if TYPE_CHECKING:
    from job_store import JobStore


logger = logging.getLogger(__name__)
TASK_DEADLINE_SECONDS = 900
WORKER_LEASE_SECONDS = 1200
TASK_RPC_TIMEOUT_SECONDS = 10.0
WORKER_TASK_PATH = "/tasks/score-step"


@dataclass(frozen=True)
class QueueConfig:
    project: str
    location: str
    queue: str
    worker_url: str
    service_account_email: str
    deadline_seconds: int = TASK_DEADLINE_SECONDS

    def __post_init__(self):
        if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", self.project):
            raise ValueError("GOOGLE_CLOUD_PROJECT must be your Google Cloud project ID.")
        if not re.fullmatch(r"[a-z]+(?:-[a-z0-9]+)+", self.location):
            raise ValueError("CLOUD_TASKS_LOCATION must be a Google Cloud region.")
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", self.queue):
            raise ValueError("CLOUD_TASKS_QUEUE contains an invalid queue name.")
        parsed = urlsplit(self.worker_url)
        if (parsed.scheme != "https" or not parsed.hostname
                or not parsed.hostname.endswith(".run.app")
                or parsed.username is not None or parsed.password is not None
                or parsed.port is not None or parsed.path not in ("", "/")
                or parsed.query or parsed.fragment):
            raise ValueError("WORKER_URL must be the private worker's root HTTPS .run.app URL.")
        if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]@" + re.escape(self.project)
                            + r"\.iam\.gserviceaccount\.com", self.service_account_email):
            raise ValueError("TASKS_SERVICE_ACCOUNT must be the dedicated service account in this project.")
        if (isinstance(self.deadline_seconds, bool)
                or not isinstance(self.deadline_seconds, int)
                or not 1 <= self.deadline_seconds <= TASK_DEADLINE_SECONDS):
            raise ValueError("Task deadlines must be between 1 and 900 seconds.")

    @classmethod
    def from_env(cls):
        return cls(
            project=os.getenv("GOOGLE_CLOUD_PROJECT", ""),
            location=os.getenv("CLOUD_TASKS_LOCATION", "us-central1"),
            queue=os.getenv("CLOUD_TASKS_QUEUE", "miru-research"),
            worker_url=os.getenv("WORKER_URL", ""),
            service_account_email=os.getenv("TASKS_SERVICE_ACCOUNT", ""),
        )


class TaskQueue:
    """Authenticated, named task delivery; research runs in the worker later."""

    def __init__(self, config: QueueConfig, *, client=None):
        self.config = config
        self.client = client if client is not None else tasks_v2.CloudTasksClient()
        self.parent = tasks_v2.CloudTasksClient.queue_path(
            config.project, config.location, config.queue,
        )
        self.worker_url = config.worker_url.rstrip("/")

    def enqueue(self, ticket: dict[str, Any]) -> str:
        """Send a reservation from JobStore.reserve_dispatch.

        A repeated send of the SAME ticket uses the same Cloud Task name.
        Later recovery reservations have a different dispatch_number. The
        worker still uses Firestore leases/revisions to handle duplicates.
        """
        job_id = ticket.get("job_id")
        revision = ticket.get("revision")
        dispatch_number = ticket.get("dispatch_number")
        if not isinstance(job_id, str) or not re.fullmatch(r"[a-f0-9]{32}", job_id):
            raise ValueError("The dispatch ticket has an invalid job ID.")
        for name, value, minimum in (("revision", revision, 0),
                                      ("dispatch_number", dispatch_number, 1)):
            if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
                raise ValueError(f"The dispatch ticket has an invalid {name}.")

        digest = hashlib.sha256(f"{job_id}:{revision}:{dispatch_number}".encode()).hexdigest()
        task_name = f"{self.parent}/tasks/miru-{digest}"
        body = json.dumps({"job_id": job_id, "revision": revision},
                          separators=(",", ":")).encode("utf-8")
        task = tasks_v2.Task(
            name=task_name,
            http_request=tasks_v2.HttpRequest(
                http_method=tasks_v2.HttpMethod.POST,
                url=self.worker_url + WORKER_TASK_PATH,
                headers={"Content-Type": "application/json"},
                body=body,
                oidc_token=tasks_v2.OidcToken(
                    service_account_email=self.config.service_account_email,
                    audience=self.worker_url,
                ),
            ),
            dispatch_deadline=Duration(seconds=self.config.deadline_seconds),
        )
        try:
            response = self.client.create_task(
                request=tasks_v2.CreateTaskRequest(parent=self.parent, task=task),
                retry=None,
                timeout=TASK_RPC_TIMEOUT_SECONDS,
            )
        except AlreadyExists:
            # A previous create may have succeeded before its response was lost.
            return task_name
        return response.name


def dispatch_job(store: JobStore, queue: TaskQueue, job_id: str) -> bool:
    """Try to queue a saved job. Return False if it is not due for delivery.

    Failure never removes the durable job. A scheduled recovery pass must call
    dispatch_pending regularly, including when the phone is disconnected.
    """
    ticket = store.reserve_dispatch(job_id)
    if ticket is None:
        return False
    try:
        queue.enqueue(ticket)
    except Exception:
        try:
            store.dispatch_failed(ticket)
        except Exception:
            logger.exception("Could not release dispatch reservation for job %s", job_id)
        raise
    return True


def dispatch_pending(store: JobStore, queue: TaskQueue) -> dict[str, int]:
    """Recover dispatches for the bounded active-job list.

    This needs a private scheduled endpoint in the worker. Merely importing
    this module or running the public API does not schedule recovery.
    """
    counts = {"enqueued": 0, "deferred": 0, "errors": 0}
    for job_id in store.active_job_ids():
        try:
            sent = dispatch_job(store, queue, job_id)
        except Exception:
            logger.exception("Task dispatch failed for job %s", job_id)
            counts["errors"] += 1
        else:
            counts["enqueued" if sent else "deferred"] += 1
    return counts
