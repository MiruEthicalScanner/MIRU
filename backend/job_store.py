from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import json
import re
from typing import Any, Callable
from uuid import uuid4
import zlib

from google.cloud import firestore


class AdmissionError(Exception):
    """The queue or daily admission allowance is full."""


class JobBusyError(Exception):
    """Another worker currently holds the job lease."""


class LeaseLostError(Exception):
    """The caller no longer owns this job's current processing step."""


TERMINAL_STATUSES = {"completed", "failed"}
MAX_JSON_BYTES = 8 * 1024 * 1024
PART_BYTES = 500_000


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _encode(value: Any) -> bytes:
    raw = json.dumps(value, ensure_ascii=False, allow_nan=False,
                     separators=(",", ":")).encode("utf-8")
    if len(raw) > MAX_JSON_BYTES:
        raise ValueError("Stored assessment data exceeds the 8 MiB limit.")
    return zlib.compress(raw)


def _decode(value: bytes) -> Any:
    return json.loads(zlib.decompress(value))


def _component(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", value):
        raise ValueError("Invalid Firestore collection or job identifier.")
    return value


def _payload(request: dict[str, Any]) -> dict[str, Any]:
    result = {}
    for key in ("product_name", "company_name"):
        value = request.get(key)
        if not isinstance(value, str) or not 1 <= len(value.strip()) <= 500:
            raise ValueError(f"{key} must contain between 1 and 500 characters.")
        result[key] = value.strip()
    choice = request.get("animal_rubric_type")
    if choice not in (None, "animal_products", "non_animal_products"):
        raise ValueError("Invalid animal rubric type.")
    result["animal_rubric_type"] = choice
    return result


class JobStore:
    """Shared job state, checkpoints, quotas, leases, and dispatch recovery.

    Defaults target a small beta. ``version`` must identify the scoring code
    used by both API and worker, so changed rubrics cannot reuse old scores.
    Firestore transactions contain database operations only, never AI calls.
    """

    def __init__(self, *, version: str, project: str | None = None,
                 prefix: str = "miru", max_pending: int = 5,
                 daily_limit: int = 10, cache_seconds: int = 86400,
                 client=None, clock: Callable[[], datetime] = _utcnow):
        if not version:
            raise ValueError("A scoring version is required.")
        if min(max_pending, daily_limit, cache_seconds) < 1 or max_pending > 100:
            raise ValueError("Limits must be positive; max_pending cannot exceed 100.")
        _component(prefix)
        self.client = client if client is not None else firestore.Client(project=project)
        self.version = version
        self.max_pending = max_pending
        self.daily_limit = daily_limit
        self.cache_seconds = cache_seconds
        self.clock = clock
        self.jobs = self.client.collection(f"{prefix}_jobs")
        self.cache = self.client.collection(f"{prefix}_cache")
        self.control = self.client.collection(f"{prefix}_meta").document("control")

    def _ref(self, job_id):
        return self.jobs.document(_component(job_id))

    def _run(self, callback):
        return firestore.transactional(callback)(self.client.transaction())

    @staticmethod
    def _read(reference, transaction):
        snapshot = reference.get(transaction=transaction)
        return snapshot.to_dict() if snapshot.exists else None

    @staticmethod
    def _owned(record, token):
        if not record or record["status"] != "running" or record.get("lease_token") != token:
            raise LeaseLostError("This worker no longer owns the processing step.")

    def create_job(self, request: dict[str, Any]) -> str:
        """Atomically admit or reuse a job; its initial dispatch is durable."""
        payload = _payload(request)
        fingerprint = hashlib.sha256(json.dumps(
            {"version": self.version, "request": payload},
            sort_keys=True, separators=(",", ":"),
        ).encode()).hexdigest()
        cache_ref = self.cache.document(fingerprint)
        job_id = uuid4().hex
        job_ref = self._ref(job_id)

        def create(transaction):
            now = self.clock()
            control = self._read(self.control, transaction) or {}
            cached = self._read(cache_ref, transaction)
            previous = self._read(self._ref(cached["job_id"]), transaction) if cached else None
            if previous and (previous["status"] not in TERMINAL_STATUSES or (
                previous["status"] == "completed" and previous["updated_at"] >
                now - timedelta(seconds=self.cache_seconds)
            )):
                return cached["job_id"]

            active = list(control.get("active_job_ids", []))
            day = now.date().isoformat()
            count = control.get("admitted", 0) if control.get("day") == day else 0
            if len(active) >= self.max_pending:
                raise AdmissionError("The scoring queue is full. Please try again later.")
            if count >= self.daily_limit:
                raise AdmissionError("The test server's daily scoring limit has been reached. Try again tomorrow (UTC).")
            record = {
                "request": payload, "version": self.version,
                "status": "queued", "error": None,
                "created_at": now, "updated_at": now,
                "revision": 0, "step_attempts": 0,
                "lease_token": None, "lease_until": None,
                "dispatch_number": 0, "dispatch_after": now,
                "result_parts": 0,
            }
            transaction.create(job_ref, record)
            transaction.set(cache_ref, {"job_id": job_id})
            transaction.set(self.control, {
                "active_job_ids": [*active, job_id], "day": day, "admitted": count + 1,
            })
            return job_id

        return self._run(create)

    def get_record(self, job_id: str) -> dict[str, Any] | None:
        """Internal metadata; the API must not expose this whole document."""
        snapshot = self._ref(job_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def get_job(self, job_id: str) -> dict[str, Any] | None:
        """Return the existing public job-status fields expected by Flutter."""
        record = self.get_record(job_id)
        if record is None:
            return None
        result = None
        if record["status"] == "completed":
            count = record["result_parts"]
            if count < 1:
                raise RuntimeError("Completed job has no saved result.")
            parts = []
            for index in range(count):
                part = self._ref(job_id).collection("result_parts").document(str(index)).get()
                if not part.exists:
                    raise RuntimeError("Saved job result is incomplete.")
                parts.append(part.to_dict()["payload"])
            result = _decode(b"".join(parts))
        return {"job_id": job_id, "status": record["status"],
                "result": result, "error": record.get("error")}

    def get_checkpoint(self, job_id: str, key: str) -> Any | None:
        checkpoint_id = hashlib.sha256(key.encode()).hexdigest()
        snapshot = self._ref(job_id).collection("checkpoints").document(checkpoint_id).get()
        if not snapshot.exists:
            return None
        data = snapshot.to_dict()
        return _decode(data["payload"])

    def active_job_ids(self) -> list[str]:
        """Bounded list for dispatch recovery, avoiding a custom query index."""
        snapshot = self.control.get()
        return list((snapshot.to_dict() or {}).get("active_job_ids", [])) if snapshot.exists else []

    def reserve_dispatch(self, job_id: str, *, watchdog_seconds: int = 180):
        """Reserve one delivery; a scheduled recovery pass retries missed sends.

        The future dispatcher MUST use this ticket's job_id, revision and
        dispatch_number in its Cloud Task name, and run periodically even when
        no new requests arrive. Creating a task is outside this transaction.
        """
        if watchdog_seconds < 1:
            raise ValueError("watchdog_seconds must be positive.")
        reference = self._ref(job_id)

        def reserve(transaction):
            record = self._read(reference, transaction)
            now = self.clock()
            if not record or record["status"] in TERMINAL_STATUSES:
                return None
            if record.get("lease_until") and record["lease_until"] > now:
                return None
            if record["dispatch_after"] > now:
                return None
            number = record["dispatch_number"] + 1
            transaction.update(reference, {
                "dispatch_number": number,
                "dispatch_after": now + timedelta(seconds=watchdog_seconds),
            })
            return {"job_id": job_id, "revision": record["revision"], "dispatch_number": number}

        return self._run(reserve)

    def dispatch_failed(self, ticket: dict[str, Any]):
        reference = self._ref(ticket["job_id"])

        def release(transaction):
            record = self._read(reference, transaction)
            if record and record["status"] not in TERMINAL_STATUSES and (
                record["revision"], record["dispatch_number"]
            ) == (ticket["revision"], ticket["dispatch_number"]):
                transaction.update(reference, {"dispatch_after": self.clock() + timedelta(seconds=30)})

        self._run(release)

    def claim_step(self, job_id: str, revision: int, *, lease_seconds: int = 1200,
                   max_attempts: int = 3) -> dict[str, Any] | None:
        """Claim one step; duplicates/stale deliveries cannot overwrite it.

        The worker's HTTP/task timeouts must be shorter than this lease.
        Returned token must accompany every checkpoint/final/error write.
        """
        if lease_seconds < 1 or max_attempts < 1:
            raise ValueError("Lease and attempt limits must be positive.")
        reference = self._ref(job_id)
        token = uuid4().hex

        def claim(transaction):
            record = self._read(reference, transaction)
            now = self.clock()
            if not record or record["status"] in TERMINAL_STATUSES or record["revision"] != revision:
                return None
            if record.get("lease_until") and record["lease_until"] > now:
                raise JobBusyError("Another worker is processing this job.")
            if record["version"] != self.version or record["step_attempts"] >= max_attempts:
                control = self._read(self.control, transaction) or {}
                error = ("The scoring rules changed while this job was waiting. Please submit again."
                         if record["version"] != self.version else
                         "Research was interrupted repeatedly. Please try again.")
                self._terminal(transaction, reference, record, control,
                               status="failed", error=error)
                return None
            updated = {
                "status": "running", "lease_token": token,
                "lease_until": now + timedelta(seconds=lease_seconds),
                "step_attempts": record["step_attempts"] + 1,
                "updated_at": now,
            }
            transaction.update(reference, updated)
            return {**record, **updated, "job_id": job_id}

        return self._run(claim)

    def save_checkpoint(self, job_id: str, token: str, key: str, data: Any):
        """Atomically save one finished step and make the next step dispatchable."""
        encoded = _encode(data)
        if len(encoded) > PART_BYTES:
            raise ValueError("One category checkpoint exceeds the storage limit.")
        reference = self._ref(job_id)
        checkpoint_id = hashlib.sha256(key.encode()).hexdigest()
        checkpoint = reference.collection("checkpoints").document(checkpoint_id)

        def save(transaction):
            record = self._read(reference, transaction)
            self._owned(record, token)
            now = self.clock()
            transaction.set(checkpoint, {"key": key, "payload": encoded})
            transaction.update(reference, {
                "status": "queued", "revision": record["revision"] + 1,
                "step_attempts": 0, "lease_token": None, "lease_until": None,
                "updated_at": now, "dispatch_after": now,
            })

        self._run(save)

    def save_progress(self, job_id: str, token: str, key: str, data: Any):
        """Save one parallel operation without releasing the shared job lease.

        Each category has a distinct checkpoint. The transaction reads the job
        before writing, so a replaced worker cannot overwrite newer progress.
        The caller must wait for its category threads before advancing/retrying.
        """
        encoded = _encode(data)
        if len(encoded) > PART_BYTES:
            raise ValueError("One category checkpoint exceeds the storage limit.")
        reference = self._ref(job_id)
        checkpoint_id = hashlib.sha256(key.encode()).hexdigest()
        checkpoint = reference.collection("checkpoints").document(checkpoint_id)

        def save(transaction):
            record = self._read(reference, transaction)
            self._owned(record, token)
            transaction.set(checkpoint, {"key": key, "payload": encoded})

        self._run(save)

    def advance_step(self, job_id: str, token: str):
        """Release a finished batch and make its next delivery dispatchable."""
        reference = self._ref(job_id)

        def advance(transaction):
            record = self._read(reference, transaction)
            self._owned(record, token)
            now = self.clock()
            transaction.update(reference, {
                "status": "queued", "revision": record["revision"] + 1,
                "step_attempts": 0, "lease_token": None, "lease_until": None,
                "updated_at": now, "dispatch_after": now,
            })

        self._run(advance)

    def retry_step(self, job_id: str, token: str, *, reset_attempts: bool = False):
        """Release a failed attempt without discarding earlier checkpoints."""
        reference = self._ref(job_id)

        def release(transaction):
            record = self._read(reference, transaction)
            self._owned(record, token)
            now = self.clock()
            transaction.update(reference, {
                "status": "queued", "lease_token": None, "lease_until": None,
                "step_attempts": 0 if reset_attempts else record["step_attempts"],
                "updated_at": now, "dispatch_after": now + timedelta(seconds=30),
            })

        self._run(release)

    def _terminal(self, transaction, reference, record, control, *, status, error=None, parts=0):
        transaction.update(reference, {
            "status": status, "error": error, "result_parts": parts,
            "lease_token": None, "lease_until": None, "updated_at": self.clock(),
        })
        control["active_job_ids"] = [item for item in control.get("active_job_ids", []) if item != reference.id]
        transaction.set(self.control, control)

    def complete_job(self, job_id: str, token: str, result: dict[str, Any]):
        """Publish result parts and completed status in the same transaction."""
        encoded = _encode(result)
        parts = [encoded[i:i + PART_BYTES] for i in range(0, len(encoded), PART_BYTES)]
        reference = self._ref(job_id)

        def complete(transaction):
            record = self._read(reference, transaction)
            self._owned(record, token)
            control = self._read(self.control, transaction) or {}
            for index, part in enumerate(parts):
                transaction.set(reference.collection("result_parts").document(str(index)), {"payload": part})
            self._terminal(transaction, reference, record, control, status="completed", parts=len(parts))

        self._run(complete)

    def fail_job(self, job_id: str, token: str, message: str):
        """Save a safe user-facing error; do not pass secrets or tracebacks."""
        reference = self._ref(job_id)

        def fail(transaction):
            record = self._read(reference, transaction)
            self._owned(record, token)
            control = self._read(self.control, transaction) or {}
            self._terminal(transaction, reference, record, control,
                           status="failed", error=message[:500] or "Scoring failed. Please try again.")

        self._run(fail)
