from __future__ import annotations

import argparse
import json
import plistlib
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

SUPABASE_URL = "https://pjxncveymixxdntplchb.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_0CPL9An-gAReMKpoDYhMtg_Da6Lc3qb"
ROOT = Path(__file__).resolve().parents[1]
BACKUPS_DIR = ROOT / "backups"
SHARED_PREFS_PATHS = [
    Path.home()
    / "Library/Containers/com.example.dicsaOperacion/Data/Library/Preferences/com.example.dicsaOperacion.plist",
    Path.home()
    / "Library/Containers/DICSA.dicsa-operacion/Data/Library/Preferences/DICSA.dicsa-operacion.plist",
]
TARGET_STATUSES = {
    "pendienteCheque",
    "chequeRecibido",
    "chequePendienteCanje",
}
FINAL_STATUSES = {
    "chequeCanjeado",
    "cancelada",
    "porRevisar",
}


@dataclass(frozen=True)
class CandidateRow:
    id: str
    ticket: str
    client_name: str
    status: str
    approved_amount: float
    paid_amount: float
    document_number: str
    document_date: str | None
    settlement_date: str | None

    @property
    def next_paid_amount(self) -> float:
        return self.approved_amount


def resolve_bearer_token() -> str:
    for path in SHARED_PREFS_PATHS:
        if not path.exists():
            continue
        try:
            with path.open("rb") as fh:
                payload = plistlib.load(fh)
            raw = payload.get("flutter.sb-pjxncveymixxdntplchb-auth-token")
            if not raw:
                continue
            session = json.loads(raw)
            token = str(session.get("access_token") or "").strip()
            if token:
                return token
        except Exception:
            continue
    raise RuntimeError("No se pudo resolver el token autenticado de Supabase.")


def supabase_request(
    method: str,
    path: str,
    token: str,
    *,
    query: dict[str, str] | None = None,
    payload: dict | None = None,
    extra_headers: dict[str, str] | None = None,
) -> tuple[int, dict[str, str], str]:
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    if query:
        url = f"{url}?{urlencode(query)}"
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if extra_headers:
        headers.update(extra_headers)
    request = Request(url, data=body, method=method, headers=headers)
    try:
        with urlopen(request) as response:
            return response.status, dict(response.headers.items()), response.read().decode("utf-8")
    except HTTPError as exc:
        body_text = exc.read().decode("utf-8", errors="replace")
        return exc.code, dict(exc.headers.items()), body_text


def fetch_rows(token: str) -> list[CandidateRow]:
    rows: list[CandidateRow] = []
    offset = 0
    page_size = 1000
    while True:
        status, _, body = supabase_request(
            "GET",
            "mayoreo_accounts",
            token,
            query={
                "select": ",".join(
                    [
                        "id",
                        "ticket",
                        "client_name_snapshot",
                        "operation_type",
                        "status",
                        "approved_amount",
                        "paid_amount",
                        "document_number",
                        "document_date",
                        "settlement_date",
                    ]
                ),
                "operation_type": "eq.cheque",
                "order": "sale_date.desc",
                "limit": str(page_size),
                "offset": str(offset),
            },
        )
        if status >= 300:
            raise RuntimeError(f"No se pudieron cargar los cheques de mayoreo. HTTP {status}: {body}")
        payload = json.loads(body)
        if not payload:
            break
        rows.extend(
            CandidateRow(
                id=str(item.get("id") or "").strip(),
                ticket=str(item.get("ticket") or "").strip(),
                client_name=str(item.get("client_name_snapshot") or "").strip(),
                status=str(item.get("status") or "").strip(),
                approved_amount=float(item.get("approved_amount") or 0),
                paid_amount=float(item.get("paid_amount") or 0),
                document_number=str(item.get("document_number") or "").strip(),
                document_date=item.get("document_date"),
                settlement_date=item.get("settlement_date"),
            )
            for item in payload
        )
        if len(payload) < page_size:
            break
        offset += page_size
    return rows


def summarize(rows: Iterable[CandidateRow]) -> dict[str, dict[str, float]]:
    summary: dict[str, dict[str, float]] = defaultdict(
        lambda: {"count": 0.0, "approved_total": 0.0, "paid_total": 0.0}
    )
    for row in rows:
        bucket = summary[row.status]
        bucket["count"] += 1
        bucket["approved_total"] += row.approved_amount
        bucket["paid_total"] += row.paid_amount
    return dict(summary)


def summarize_by_client(rows: Iterable[CandidateRow]) -> list[dict[str, float | str]]:
    buckets: dict[str, dict[str, float | str]] = defaultdict(
        lambda: {"cliente": "", "count": 0.0, "approved_total": 0.0}
    )
    for row in rows:
        bucket = buckets[row.client_name]
        bucket["cliente"] = row.client_name
        bucket["count"] = float(bucket["count"]) + 1
        bucket["approved_total"] = float(bucket["approved_total"]) + row.approved_amount
    return sorted(
        buckets.values(),
        key=lambda item: (-float(item["approved_total"]), str(item["cliente"])),
    )


def current_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def ensure_backup_dir() -> Path:
    path = BACKUPS_DIR / f"mayoreo_cheque_mass_close_{current_stamp()}"
    path.mkdir(parents=True, exist_ok=False)
    return path


def patch_row(token: str, row: CandidateRow, settlement_iso: str) -> None:
    status, _, body = supabase_request(
        "PATCH",
        "mayoreo_accounts",
        token,
        query={"id": f"eq.{row.id}"},
        payload={
            "status": "chequeCanjeado",
            "paid_amount": row.next_paid_amount,
            "settlement_date": settlement_iso,
        },
        extra_headers={"Prefer": "return=minimal"},
    )
    if status >= 300:
        raise RuntimeError(
            f"No se pudo actualizar {row.id} ticket {row.ticket}. HTTP {status}: {body}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Cierra masivamente cheques pendientes de canje en Mayoreo Cuentas."
    )
    parser.add_argument(
        "--date",
        required=True,
        help="Fecha contable de canje en formato YYYY-MM-DD.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Aplica el cambio en producción. Sin esta bandera solo analiza.",
    )
    parser.add_argument(
        "--include-status",
        action="append",
        dest="include_statuses",
        default=[],
        help="Estatus adicional a incluir manualmente. Puede repetirse.",
    )
    return parser.parse_args()


def validate_date(raw: str) -> str:
    parsed = date.fromisoformat(raw)
    return f"{parsed.isoformat()}T00:00:00+00:00"


def main() -> int:
    args = parse_args()
    settlement_iso = validate_date(args.date)
    token = resolve_bearer_token()
    all_rows = fetch_rows(token)
    target_statuses = set(TARGET_STATUSES) | set(args.include_statuses)
    candidates = [
        row
        for row in all_rows
        if row.status in target_statuses and row.status not in FINAL_STATUSES
    ]

    print("Resumen de cheques Mayoreo por estatus:")
    print(json.dumps(summarize(all_rows), indent=2, ensure_ascii=False))
    print()
    print("Clientes dentro del ajuste candidato:")
    print(json.dumps(summarize_by_client(candidates), indent=2, ensure_ascii=False))
    print()
    print(
        json.dumps(
            {
                "candidate_count": len(candidates),
                "candidate_total_approved": round(
                    sum(row.approved_amount for row in candidates), 2
                ),
                "candidate_total_paid_before": round(
                    sum(row.paid_amount for row in candidates), 2
                ),
                "settlement_date_to_apply": settlement_iso,
                "target_statuses": sorted(target_statuses),
            },
            indent=2,
            ensure_ascii=False,
        )
    )

    if not args.apply:
        return 0

    if not candidates:
        print("No hay filas candidatas para actualizar.")
        return 0

    backup_dir = ensure_backup_dir()
    before_payload = [
        {
            "id": row.id,
            "ticket": row.ticket,
            "client_name_snapshot": row.client_name,
            "status": row.status,
            "approved_amount": row.approved_amount,
            "paid_amount": row.paid_amount,
            "document_number": row.document_number,
            "document_date": row.document_date,
            "settlement_date": row.settlement_date,
        }
        for row in candidates
    ]
    (backup_dir / "before_rows.json").write_text(
        json.dumps(before_payload, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (backup_dir / "apply_meta.json").write_text(
        json.dumps(
            {
                "applied_at_utc": datetime.now(timezone.utc).isoformat(),
                "settlement_date_applied": settlement_iso,
                "candidate_count": len(candidates),
                "candidate_total_approved": round(
                    sum(row.approved_amount for row in candidates), 2
                ),
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    for row in candidates:
        patch_row(token, row, settlement_iso)

    refreshed_rows = fetch_rows(token)
    refreshed_by_id = {row.id: row for row in refreshed_rows}
    after_payload = [
        {
            "id": row.id,
            "ticket": row.ticket,
            "client_name_snapshot": row.client_name,
            "status": refreshed_by_id[row.id].status if row.id in refreshed_by_id else None,
            "approved_amount": refreshed_by_id[row.id].approved_amount
            if row.id in refreshed_by_id
            else None,
            "paid_amount": refreshed_by_id[row.id].paid_amount if row.id in refreshed_by_id else None,
            "document_number": refreshed_by_id[row.id].document_number
            if row.id in refreshed_by_id
            else None,
            "document_date": refreshed_by_id[row.id].document_date
            if row.id in refreshed_by_id
            else None,
            "settlement_date": refreshed_by_id[row.id].settlement_date
            if row.id in refreshed_by_id
            else None,
        }
        for row in candidates
    ]
    (backup_dir / "after_rows.json").write_text(
        json.dumps(after_payload, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print()
    print(f"Ajuste aplicado. Respaldo guardado en: {backup_dir}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - operational script
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
