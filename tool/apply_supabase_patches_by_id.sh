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
  echo "jq es requerido para aplicar patches" >&2
  exit 1
fi

SNAPSHOT_DIR="$1"
shift

patch_table() {
  local table="$1"
  local input_file="${SNAPSHOT_DIR}/${table}.json"
  if [[ ! -f "${input_file}" ]]; then
    echo "No existe ${input_file}, se omite ${table}"
    return
  fi

  local total
  total="$(jq 'length' "${input_file}")"
  if [[ "${total}" == "0" ]]; then
    echo "Sin patches para ${table}"
    return
  fi

  local applied=0
  while IFS= read -r row; do
    local id
    id="$(printf '%s' "${row}" | jq -r '.id // ""')"
    if [[ -z "${id}" ]]; then
      echo "Fila sin id en ${table}, se omite" >&2
      continue
    fi

    local payload
    payload="$(printf '%s' "${row}" | jq -c 'del(.id)')"
    if [[ "${payload}" == "{}" ]]; then
      continue
    fi

    local encoded_id
    encoded_id="$(jq -rn --arg v "${id}" '$v|@uri')"

    local response
    response="$(
      curl -sS -w '\n%{http_code}' \
        -X PATCH \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=minimal" \
        "${SUPABASE_URL}/rest/v1/${table}?id=eq.${encoded_id}" \
        --data-binary "${payload}"
    )"
    local http_code="${response##*$'\n'}"
    local body="${response%$'\n'*}"
    if [[ "${http_code}" -lt 200 || "${http_code}" -ge 300 ]]; then
      echo "Fallo patch ${table}:${id} -> HTTP ${http_code}" >&2
      if [[ -n "${body}" ]]; then
        echo "${body}" >&2
      fi
      exit 1
    fi
    applied=$((applied + 1))
  done < <(jq -c '.[]' "${input_file}")

  echo "Aplicados ${applied} patches en ${table}"
}

for table in "$@"; do
  patch_table "${table}"
done
