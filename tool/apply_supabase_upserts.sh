#!/bin/zsh

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: $0 <snapshot_dir> <table1> [table2 ...]" >&2
  exit 1
fi

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "Falta SUPABASE_URL" >&2
  exit 1
fi

SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SUPABASE_API_KEY:-}}"
if [[ -z "${SUPABASE_KEY}" ]]; then
  echo "Falta SUPABASE_SERVICE_ROLE_KEY o SUPABASE_API_KEY" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq es requerido para aplicar upserts" >&2
  exit 1
fi

SNAPSHOT_DIR="$1"
shift
BATCH_SIZE="${SUPABASE_UPSERT_BATCH_SIZE:-200}"
ON_CONFLICT="${SUPABASE_ON_CONFLICT:-id}"

apply_table() {
  local table="$1"
  local input_file="${SNAPSHOT_DIR}/${table}.json"
  if [[ ! -f "${input_file}" ]]; then
    echo "No existe ${input_file}, se omite ${table}"
    return
  fi

  local total
  total="$(jq 'length' "${input_file}")"
  if [[ "${total}" == "0" ]]; then
    echo "Sin upserts para ${table}"
    return
  fi

  local offset=0
  while [[ "${offset}" -lt "${total}" ]]; do
    local next_offset=$((offset + BATCH_SIZE))
    local payload
    payload="$(jq -c ".[$offset:${next_offset}]" "${input_file}")"
    curl -s \
      -X POST \
      -H "apikey: ${SUPABASE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_KEY}" \
      -H "Content-Type: application/json" \
      -H "Prefer: resolution=merge-duplicates,return=minimal" \
      "${SUPABASE_URL}/rest/v1/${table}?on_conflict=${ON_CONFLICT}" \
      --data-binary "${payload}" \
      >/dev/null
    offset="${next_offset}"
  done

  echo "Aplicados ${total} upserts en ${table}"
}

for table in "$@"; do
  apply_table "${table}"
done
