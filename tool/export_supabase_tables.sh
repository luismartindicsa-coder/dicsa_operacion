#!/bin/zsh

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: $0 <output_dir> <table1> [table2 ...]" >&2
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
  echo "jq es requerido para exportar tablas" >&2
  exit 1
fi

OUTPUT_DIR="$1"
shift
PAGE_SIZE="${SUPABASE_EXPORT_PAGE_SIZE:-1000}"

mkdir -p "${OUTPUT_DIR}"

fetch_table() {
  local table="$1"
  local output_file="${OUTPUT_DIR}/${table}.json"
  local temp_dir
  temp_dir="$(mktemp -d)"
  local offset=0
  local page=0

  while true; do
    local chunk_file="${temp_dir}/chunk_${page}.json"
    curl -s \
      -H "apikey: ${SUPABASE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_KEY}" \
      -H "Range-Unit: items" \
      "${SUPABASE_URL}/rest/v1/${table}?select=*&limit=${PAGE_SIZE}&offset=${offset}" \
      > "${chunk_file}"

    local chunk_count
    chunk_count="$(jq 'length' "${chunk_file}")"
    if [[ "${chunk_count}" == "0" ]]; then
      break
    fi

    offset=$((offset + PAGE_SIZE))
    page=$((page + 1))

    if [[ "${chunk_count}" -lt "${PAGE_SIZE}" ]]; then
      break
    fi
  done

  if [[ "${page}" -eq 0 ]]; then
    printf '[]\n' > "${output_file}"
  else
    jq -s 'add' "${temp_dir}"/chunk_*.json > "${output_file}"
  fi

  rm -rf "${temp_dir}"
  echo "Exportada ${table} -> ${output_file}"
}

for table in "$@"; do
  fetch_table "${table}"
done
