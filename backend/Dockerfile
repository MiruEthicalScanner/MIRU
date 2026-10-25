FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    MIRU_BACKEND_MODE=cloud

WORKDIR /app

RUN useradd --create-home --uid 10001 --user-group miru

COPY --chown=miru:miru requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt

# no explicit file copies: local secrets, archives, and venvs
COPY --chown=miru:miru app.py worker_app.py cloud_config.py \
    job_store.py task_queue.py job_worker.py \
    rubrics.py scorer.py score_service.py ./

COPY --chown=miru:miru research/__init__.py research/rubric_selector.py \
    research/web_researcher.py research/analyzer.py ./research/

USER miru

# Cloud Run deployment will use port 8080
EXPOSE 8080

ENTRYPOINT ["python", "-m", "uvicorn"]
CMD ["app:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
