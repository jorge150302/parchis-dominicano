#!/usr/bin/env bash
# Runs a command up to 3 times, retrying only when it failed on a network
# download (Maven/Google/GitHub timeouts or 5xx). Any other failure, such as
# a compile error, fails at once so real problems aren't retried or hidden.
#   .github/scripts/retry-on-network-error.sh flutter build apk --debug
set -uo pipefail
network_error='Could not (download|resolve|GET|HEAD)|Gateway Time-?out|Read timed out|Connection (reset|refused|timed out)|50[234] from server|Received status code 5[0-9][0-9]'
log="$(mktemp)"
for attempt in 1 2 3; do
  "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  [ "$status" -eq 0 ] && exit 0
  if ! grep -Eq "$network_error" "$log"; then
    exit "$status"
  fi
  echo "::warning::Network error downloading dependencies (attempt $attempt of 3); retrying in 30 s"
  sleep 30
done
exit "$status"
