#!/usr/bin/env bash
set -euo pipefail

############################################
# DEFAULTS (overridable via env/args)
############################################

PAGE_SIZE=100
PARALLEL=100

# 0 = rely on auto-run-on-upload
# 1 = explicitly POST /runs (requires user/team token)
CREATE_RUN=0
RUN_MESSAGE="Queued via API driven run workflow blast"

############################################

usage() {
  cat <<'EOF'
Usage:
  blast_api_driven_runs.sh [options] <path_to_content_directory> [workspace_name_prefix_filter]

Required (via env or flags):
  TFE_TOKEN       or --token/-t
  TFE_HOSTNAME    or --hostname/-H   (e.g. tfe.example.com or https://tfe.example.com)
  TFE_ORG         or --org/-o

Optional:
  --page-size N       (default: 100)
  --parallel N        (default: 100)
  --create-run 0|1    (default: 0)
  --run-message TEXT  (default: "Queued via API driven run workflow blast")
  --help

Examples:
  TFE_TOKEN=... TFE_HOSTNAME=tfe.example.com TFE_ORG=myorg ./blast_api_driven_runs.sh ./content
  ./blast_api_driven_runs.sh -t "$TFE_TOKEN" -H tfe.example.com -o myorg ./content prefix-
EOF
  exit 1
}

die() { echo "ERROR: $*" >&2; exit 1; }

# -------------------------
# Parse options (env first, flags override)
# -------------------------
TOKEN="${TFE_TOKEN:-}"
TFE_HOSTNAME="${TFE_HOSTNAME:-}"
ORG="${TFE_ORG:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--token)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      TOKEN="$2"; shift 2
      ;;
    -H|--hostname)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      TFE_HOSTNAME="$2"; shift 2
      ;;
    -o|--org)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      ORG="$2"; shift 2
      ;;
    --page-size)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      PAGE_SIZE="$2"; shift 2
      ;;
    --parallel)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      PARALLEL="$2"; shift 2
      ;;
    --create-run)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      CREATE_RUN="$2"; shift 2
      ;;
    --run-message)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      RUN_MESSAGE="$2"; shift 2
      ;;
    -h|--help)
      usage
      ;;
    --) shift; break ;;
    -*) die "Unknown option: $1 (use --help)" ;;
    *) break ;;
  esac
done

CONTENT_DIR="${1:-}"
NAME_PREFIX="${2:-}"   # optional: only workspaces whose name starts with this
[[ -n "$CONTENT_DIR" ]] || usage

[[ -n "$TOKEN" ]] || die "TFE token not set. Provide TFE_TOKEN or --token/-t"
[[ -n "$TFE_HOSTNAME" ]] || die "TFE hostname not set. Provide TFE_HOSTNAME or --hostname/-H"
[[ -n "$ORG" ]] || die "TFE org not set. Provide TFE_ORG or --org/-o"

# Normalize hostname -> address
# Accept: tfe.example.com OR https://tfe.example.com
TFE_HOSTNAME="${TFE_HOSTNAME#http://}"
TFE_HOSTNAME="${TFE_HOSTNAME#https://}"
TFE_HOSTNAME="${TFE_HOSTNAME%/}"
TFE_ADDR="https://${TFE_HOSTNAME}"

command -v jq >/dev/null || die "jq is required"
command -v curl >/dev/null || die "curl is required"
command -v tar >/dev/null || die "tar is required"

# 1) Create tar.gz ONCE (in /tmp so we don't accidentally tar the tarball itself)
UPLOAD_FILE="$(mktemp -t tfcontent.XXXXXX).tar.gz"
tar -zcf "$UPLOAD_FILE" -C "$CONTENT_DIR" .

cleanup() { rm -f "$UPLOAD_FILE"; }
trap cleanup EXIT

auth_hdr=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/vnd.api+json")

api_get() {
  local url="$1"
  curl -g -fsS "${auth_hdr[@]}" "$url"
}

api_post_json() {
  local url="$1" data="$2"
  curl -g -fsS "${auth_hdr[@]}" -X POST --data "$data" "$url"
}

list_workspaces() {
  local page=1
  while :; do
    local url="$TFE_ADDR/api/v2/organizations/$ORG/workspaces?page[number]=$page&page[size]=$PAGE_SIZE"
    local resp
    resp="$(api_get "$url")"

    # emit: "<ws_id>\t<ws_name>"
    echo "$resp" | jq -r '.data[] | [.id, .attributes.name] | @tsv'

    # stop when there is no next link
    local next
    next="$(echo "$resp" | jq -r '.links.next // empty')"
    [[ -n "$next" ]] || break

    page=$((page + 1))
  done
}

do_one_workspace() {
  local ws_id="$1"
  local ws_name="$2"

  if [[ -n "$NAME_PREFIX" && "$ws_name" != "$NAME_PREFIX"* ]]; then
    return 0
  fi

  # 2) Create configuration version; capture upload-url and configuration version id
  local cv_resp upload_url cv_id
  cv_resp="$(api_post_json \
    "$TFE_ADDR/api/v2/workspaces/$ws_id/configuration-versions" \
    '{"data":{"type":"configuration-versions"}}')"

  upload_url="$(echo "$cv_resp" | jq -r '.data.attributes."upload-url"')"
  cv_id="$(echo "$cv_resp" | jq -r '.data.id')"

  if [[ -z "$upload_url" || "$upload_url" == "null" ]]; then
    echo "ERROR $ws_name ($ws_id): did not receive upload-url" >&2
    return 1
  fi

  # 3) Upload tar.gz to upload-url (pre-signed URL; no auth header required)
  curl -fsS \
    -H "Content-Type: application/octet-stream" \
    -X PUT \
    --data-binary @"$UPLOAD_FILE" \
    "$upload_url" >/dev/null

  # 4) Optional: explicitly create a run with custom message
  if [[ "$CREATE_RUN" == "1" ]]; then
    local run_payload
    run_payload="$(cat <<JSON
{
  "data": {
    "type": "runs",
    "attributes": { "message": "$RUN_MESSAGE" },
    "relationships": {
      "workspace": { "data": { "type": "workspaces", "id": "$ws_id" } },
      "configuration-version": { "data": { "type": "configuration-versions", "id": "$cv_id" } }
    }
  }
}
JSON
)"
    api_post_json "$TFE_ADDR/api/v2/runs" "$run_payload" >/dev/null
  fi

  echo "OK  $ws_name  ($ws_id)  cv=$cv_id  create_run=$CREATE_RUN"
}

# For xargs parallelism, each worker runs in its own shell.
worker() {
  local ws_id="$1"
  local ws_name="$2"
  auth_hdr=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/vnd.api+json")
  do_one_workspace "$ws_id" "$ws_name"
}

export -f worker do_one_workspace api_get api_post_json
export TOKEN TFE_HOSTNAME TFE_ADDR ORG PAGE_SIZE CREATE_RUN RUN_MESSAGE NAME_PREFIX UPLOAD_FILE

# Stream all workspaces -> run with bounded concurrency
OUTPUT_FILE="$(mktemp -t blast-output.XXXXXX)"

list_workspaces | awk -F'\t' '{print $1, $2}' | \
  xargs -n 2 -P "$PARALLEL" bash -lc 'worker "$@"' _ | \
  tee "$OUTPUT_FILE"

# Count successful starts
SUCCESS_COUNT="$(grep -c '^OK ' "$OUTPUT_FILE" || true)"

echo
echo "========================================"
echo "Successfully started $SUCCESS_COUNT runs"
echo "========================================"

rm -f "$OUTPUT_FILE"
