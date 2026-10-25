from __future__ import annotations

from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import re
from threading import Lock

from job_store import JobStore
from job_worker import JobWorker
from task_queue import QueueConfig, TaskQueue


SCORING_FILES = (
    "rubrics.py",
    "scorer.py",
    "models.py",
    "evidence_models.py",
    "score_service.py",
    "research/rubric_selector.py",
    "research/web_researcher.py",
    "research/analyzer.py",
    "job_store.py",
    "job_worker.py",
    "cloud_config.py",
    "requirements.txt",
)


def scoring_version(source_root: Path | None = None) -> str:
    root = Path(source_root) if source_root is not None else Path(__file__).resolve().parent
    digest = hashlib.sha256(b"MIRU durable scoring version 1\x00")
    for relative in SCORING_FILES:
        try:
            contents = (root / relative).read_bytes().replace(b"\r\n", b"\n")
        except OSError as error:
            raise RuntimeError(f"Missing or unreadable scoring source file: {relative}") from error
        digest.update(relative.encode("utf-8") + b"\x00")
        digest.update(len(contents).to_bytes(8, "big"))
        digest.update(contents)
    return "miru-v1-" + digest.hexdigest()


def _integer_setting(name: str, default: int) -> int:
    value = os.getenv(name, str(default))
    if not re.fullmatch(r"[0-9]{1,10}", value):
        raise ValueError(f"{name} must be a positive whole number.")
    return int(value)


@dataclass(frozen=True)
class CloudSettings:
    queue: QueueConfig
    firestore_prefix: str = "miru"
    max_pending: int = 5
    daily_limit: int = 10
    cache_seconds: int = 86400

    def __post_init__(self):
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", self.firestore_prefix):
            raise ValueError("FIRESTORE_PREFIX must be a single collection-name prefix.")
        for name, value in (("MAX_PENDING_JOBS", self.max_pending),
                            ("DAILY_JOB_LIMIT", self.daily_limit),
                            ("CACHE_TTL_SECONDS", self.cache_seconds)):
            if isinstance(value, bool) or not isinstance(value, int) or value < 1:
                raise ValueError(f"{name} must be a positive whole number.")
        if self.max_pending > 100:
            raise ValueError("MAX_PENDING_JOBS cannot exceed 100.")

    @classmethod
    def from_env(cls) -> CloudSettings:
        """read server environment settings after the startup configuration.

        OPENAI_API_KEY is purposefully not copied into settings or job records.
        google clients use the server's attached service account credentials.
        """
        return cls(
            queue=QueueConfig.from_env(),
            firestore_prefix=os.getenv("FIRESTORE_PREFIX", "miru"),
            max_pending=_integer_setting("MAX_PENDING_JOBS", 5),
            daily_limit=_integer_setting("DAILY_JOB_LIMIT", 10),
            cache_seconds=_integer_setting("CACHE_TTL_SECONDS", 86400),
        )


@dataclass(frozen=True)
class CloudRuntime:
    settings: CloudSettings
    version: str
    store: JobStore
    queue: TaskQueue
    worker: JobWorker


def build_runtime(settings: CloudSettings | None = None, *,
                  firestore_client=None, tasks_client=None,
                  source_root: Path | None = None) -> CloudRuntime:
    settings = settings if settings is not None else CloudSettings.from_env()
    version = scoring_version(source_root)
    store = JobStore(
        version=version, project=settings.queue.project, prefix=settings.firestore_prefix,
        max_pending=settings.max_pending, daily_limit=settings.daily_limit,
        cache_seconds=settings.cache_seconds, client=firestore_client,
    )
    queue = TaskQueue(settings.queue, client=tasks_client)
    return CloudRuntime(settings=settings, version=version, store=store,
                        queue=queue, worker=JobWorker(store, queue))


_runtime: CloudRuntime | None = None
_runtime_lock = Lock()


def get_runtime() -> CloudRuntime:
    global _runtime
    with _runtime_lock:
        if _runtime is None:
            _runtime = build_runtime()
        return _runtime
