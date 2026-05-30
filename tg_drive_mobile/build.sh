#!/usr/bin/env bash
set -euo pipefail

# Load API credentials from .env
if [ -f .env ]; then
  export $(grep -v '^\s*#' .env | grep -v '^\s*$' | xargs)
else
  echo "Error: .env file not found. Create it with:"
  echo "  API_ID=your_api_id"
  echo "  API_HASH=your_api_hash"
  exit 1
fi

if [ -z "${API_ID:-}" ] || [ -z "${API_HASH:-}" ]; then
  echo "Error: API_ID or API_HASH is not set in .env"
  exit 1
fi

flutter build apk --debug \
  --dart-define=API_ID="$API_ID" \
  --dart-define=API_HASH="$API_HASH"
