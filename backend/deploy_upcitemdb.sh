#!/usr/bin/env bash
set -euo pipefail
set +x

miru_project="miru-backend-mili-2026"
miru_region="us-central1"

for miru_file in app.py worker_app.py Dockerfile requirements.txt; do
  if [[ ! -f "$miru_file" ]]; then
    printf 'Missing %s. Run from the complete backend folder.\n' "$miru_file" >&2
    exit 1
  fi
done
if ! command -v gcloud >/dev/null 2>&1; then
  printf 'The gcloud command is required.\n' >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  printf 'The curl command is required for the live check.\n' >&2
  exit 1
fi

gcloud run services describe miru-api \
  --project "$miru_project" --region "$miru_region" >/dev/null
gcloud run services describe miru-worker \
  --project "$miru_project" --region "$miru_region" >/dev/null


gcloud run deploy miru-api --source . \
  --project "$miru_project" --region "$miru_region"

miru_api_revision="$(gcloud run services describe miru-api \
  --project "$miru_project" --region "$miru_region" \
  --format='value(status.latestReadyRevisionName)')"
miru_api_image="$(gcloud run revisions describe "$miru_api_revision" \
  --project "$miru_project" --region "$miru_region" \
  --format='value(status.imageDigest)')"
case "$miru_api_image" in
  *@sha256:*) ;;
  *) printf 'Could not resolve the API image; worker update stopped.\n' >&2; exit 1 ;;
esac

gcloud run services update miru-worker \
  --project "$miru_project" --region "$miru_region" \
  --image "$miru_api_image"

printf '\nBoth deployment commands finished. Compare the images below.\n'
gcloud run services list \
  --project "$miru_project" --region "$miru_region" \
  --format='table(metadata.name,spec.template.spec.containers[0].image)'

printf '\nChecking the hosted API health.\n'

curl --fail --silent --show-error -i --max-time 30 \
  "https://miru-api-822959759707.us-central1.run.app/health" \
  --write-out '\nHTTP status: %{http_code}\n'
