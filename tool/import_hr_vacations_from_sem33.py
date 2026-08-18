from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from uuid import uuid4
from zipfile import ZipFile
from xml.etree import ElementTree as ET

SUPABASE_URL = "https://pjxncveymixxdntplchb.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_0CPL9An-gAReMKpoDYhMtg_Da6Lc3qb"
SHARED_PREFS_PATHS = [
    Path.home()
    / "Library/Containers/com.example.dicsaOperacion/Data/Library/Preferences/com.example.dicsaOperacion.plist",
    Path.home()
    / "Library/Containers/DICSA.dicsa-operacion/Data/Library/Preferences/DICSA.dicsa-operacion.plist",
]

PERIOD_PREFIX = "MIG_SEM33_VAC|"
XML_NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pr": "http://schemas.openxmlformats.org/package/2006/relationships",
}
SPANISH_MONTHS = {
    "ENERO": 1,
    "FEBRERO": 2,
    "MARZO": 3,
    "ABRIL": 4,
    "MAYO": 5,
    "JUNIO": 6,
    "JULIO": 7,
    "AGOSTO": 8,
    "SEPTIEMBRE": 9,
    "OCTUBRE": 10,
    "NOVIEMBRE": 11,
    "DICIEMBRE": 12,
}


@dataclass(frozen=True)
class EmployeeProfile:
    employee_id: str
    employee_name: str
    empresa: str
    fecha_ingreso: date | None
    fecha_alta: date | None
    salario: float
    salario_percibido: float


@dataclass(frozen=True)
class VacationBalance:
    id: str
    employee_id: str
    exercise_year: int
    base_date_policy: str
    base_fecha_ingreso: date | None
    base_fecha_alta: date | None
    antiguedad_years: int
    entitlement_rule_key: str
    days_entitled: float
    days_paid: float
    days_enjoyed: float
    days_reserved: float
    days_taken: float
    days_available: float
    salary_snapshot: float
    salary_perceived_snapshot: float
    status: str


@dataclass(frozen=True)
class VacationEvent:
    id: str
    employee_id: str
    exercise_year: int
    receipt_group_key: str
    event_type: str
    start_date: date
    end_date: date
    days_applied: float
    status: str
    impact_attendance: bool
    impact_prenomina: bool
    generate_receipt: bool
    attendance_sync_status: str
    prenomina_sync_status: str
    notes: str


@dataclass(frozen=True)
class WeeklyVacationSignal:
    employee_id: str
    employee_name: str
    empresa: str
    weekly_salary: float
    daily_rate: float
    vacation_amount: float
    vacation_days: float
    account_reference: str
    receipt_group_key: str
    period_label: str
    period_start: date
    period_end: date
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Importa vacaciones detectadas en sem33.xlsx hacia "
            "hr_employee_vacation_events y hr_employee_vacation_calculations."
        )
    )
    parser.add_argument(
        "--workbook",
        default=str(Path.home() / "Downloads/sem33.xlsx"),
        help="Ruta al archivo sem33.xlsx",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Aplica cambios en Supabase. Sin esta bandera solo hace dry-run.",
    )
    return parser.parse_args()


def resolve_supabase_bearer_token() -> str:
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
    return SUPABASE_ANON_KEY


def request_json(
    method: str,
    path: str,
    *,
    params: dict[str, str] | None = None,
    body: Any | None = None,
    prefer: str | None = None,
) -> Any:
    query = f"?{urlencode(params)}" if params else ""
    url = f"{SUPABASE_URL}/rest/v1/{path}{query}"
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {resolve_supabase_bearer_token()}",
        "Accept": "application/json",
    }
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    if prefer:
        headers["Prefer"] = prefer
    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else []
    except Exception:
        command = [
            "curl",
            "-s",
            "-X",
            method,
            url,
            "-H",
            f"apikey: {SUPABASE_ANON_KEY}",
            "-H",
            f"Authorization: Bearer {resolve_supabase_bearer_token()}",
            "-H",
            "Accept: application/json",
        ]
        if prefer:
            command.extend(["-H", f"Prefer: {prefer}"])
        if body is not None:
            command.extend(["-H", "Content-Type: application/json", "-d", json.dumps(body)])
        raw = subprocess.check_output(command, text=True)
        return json.loads(raw) if raw else []


def fetch_all(table: str, select: str, *, filters: dict[str, str] | None = None) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset = 0
    page_size = 1000
    while True:
        params = {
            "select": select,
            "limit": str(page_size),
            "offset": str(offset),
        }
        if filters:
            params.update(filters)
        payload = request_json("GET", table, params=params)
        if not payload:
            break
        rows.extend(dict(item) for item in payload)
        if len(payload) < page_size:
            break
        offset += page_size
    return rows


def post_rows(table: str, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if not rows:
        return []
    return request_json(
        "POST",
        table,
        body=rows,
        prefer="return=representation",
    )


def patch_rows(
    table: str,
    filters: dict[str, str],
    patch: dict[str, Any],
) -> list[dict[str, Any]]:
    return request_json(
        "PATCH",
        table,
        params=filters,
        body=patch,
        prefer="return=representation",
    )


def upsert_rows(
    table: str,
    rows: list[dict[str, Any]],
    *,
    on_conflict: str,
) -> list[dict[str, Any]]:
    if not rows:
        return []
    return request_json(
        "POST",
        table,
        params={"on_conflict": on_conflict},
        body=rows,
        prefer="resolution=merge-duplicates,return=representation",
    )


def parse_db_date(raw: Any) -> date | None:
    if raw in (None, ""):
        return None
    text = str(raw).strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).date()
    except ValueError:
        return None


def parse_number(raw: Any) -> float:
    if raw in (None, ""):
        return 0.0
    text = str(raw).strip()
    if not text:
        return 0.0
    text = text.replace(",", "")
    try:
        return float(text)
    except ValueError:
        return 0.0


def column_to_index(col: str) -> int:
    value = 0
    for ch in col:
        if ch.isalpha():
            value = value * 26 + ord(ch.upper()) - 64
    return value


def read_xlsx_rows(path: Path) -> tuple[list[dict[int, str]], list[str]]:
    with ZipFile(path) as archive:
        shared_strings: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            shared_root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            for item in shared_root.findall("a:si", XML_NS):
                shared_strings.append(
                    "".join(text.text or "" for text in item.iterfind(".//a:t", XML_NS))
                )

        workbook_root = ET.fromstring(archive.read("xl/workbook.xml"))
        rel_root = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        rel_map = {
            rel.attrib["Id"]: rel.attrib["Target"]
            for rel in rel_root.findall("pr:Relationship", XML_NS)
        }
        first_sheet = workbook_root.find("a:sheets", XML_NS)[0]
        target = rel_map[first_sheet.attrib["{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"]]
        target = f"xl/{target}" if not target.startswith("xl/") else target
        sheet_root = ET.fromstring(archive.read(target))
        rows: list[dict[int, str]] = []
        for row in sheet_root.findall(".//a:sheetData/a:row", XML_NS):
            values: dict[int, str] = {}
            for cell in row.findall("a:c", XML_NS):
                ref = cell.attrib.get("r", "")
                col = "".join(ch for ch in ref if ch.isalpha())
                index = column_to_index(col)
                cell_type = cell.attrib.get("t")
                value_node = cell.find("a:v", XML_NS)
                value = ""
                if value_node is not None:
                    value = value_node.text or ""
                    if cell_type == "s" and value.isdigit():
                        shared_index = int(value)
                        if 0 <= shared_index < len(shared_strings):
                            value = shared_strings[shared_index]
                values[index] = value
            rows.append(values)
        return rows, shared_strings


def extract_period_from_rows(rows: list[dict[int, str]]) -> tuple[str, date, date]:
    pattern = re.compile(
        r"SEMANA DEL\s+(\d{1,2})\s+AL\s+(\d{1,2})\s+DE\s+([A-ZÁÉÍÓÚ]+)\s+(\d{4})",
        re.IGNORECASE,
    )
    for row in rows[:12]:
        for value in row.values():
            match = pattern.search(str(value).upper())
            if not match:
                continue
            start_day = int(match.group(1))
            end_day = int(match.group(2))
            month = SPANISH_MONTHS[match.group(3).upper()]
            year = int(match.group(4))
            start_date = date(year, month, start_day)
            end_date = date(year, month, end_day)
            label = f"Periodo 33 semanal · {start_date:%d/%m/%Y} - {end_date:%d/%m/%Y}"
            return label, start_date, end_date
    raise RuntimeError("No se encontró el rango semanal dentro de sem33.xlsx")


def normalize_header(text: str) -> str:
    return re.sub(r"\s+", " ", (text or "").strip().upper())


def parse_sem33_vacation_signals(path: Path) -> tuple[str, date, date, list[dict[str, str]]]:
    rows, _ = read_xlsx_rows(path)
    period_label, period_start, period_end = extract_period_from_rows(rows)
    header_row = rows[9]
    headers = {index: value for index, value in header_row.items()}
    data_rows: list[dict[str, str]] = []
    for values in rows[10:]:
        row = {normalize_header(headers.get(index, "")): cell for index, cell in values.items()}
        if not row.get("NO.", "").strip() or not row.get("NOMBRE", "").strip():
            continue
        if normalize_header(row.get("CHEQUE", "")) != "VACACIONES":
            continue
        data_rows.append(row)
    return period_label, period_start, period_end, data_rows


def choose_entitlement_rule_key(years: int) -> tuple[str, int]:
    rules = [
        ("1_anio", 1, 1, 12),
        ("2_anios", 2, 2, 14),
        ("3_anios", 3, 3, 16),
        ("4_anios", 4, 4, 18),
        ("5_anios", 5, 5, 20),
        ("6_10_anios", 6, 10, 22),
        ("11_15_anios", 11, 15, 24),
        ("16_20_anios", 16, 20, 26),
        ("21_25_anios", 21, 25, 28),
        ("26_30_anios", 26, 30, 30),
        ("31_35_anios", 31, 35, 32),
    ]
    for key, min_years, max_years, days in rules:
        if min_years <= years <= max_years:
            return key, days
    return "0_anios", 0


def years_of_service(base_date: date | None, as_of: date) -> int:
    if base_date is None:
        return 0
    years = as_of.year - base_date.year
    if (as_of.month, as_of.day) < (base_date.month, base_date.day):
        years -= 1
    return max(years, 0)


def build_signal(
    row: dict[str, str],
    *,
    period_label: str,
    period_start: date,
    period_end: date,
    profile: EmployeeProfile,
) -> WeeklyVacationSignal:
    weekly_salary = parse_number(row.get("SUELDO")) or profile.salario_percibido or profile.salario
    daily_rate = weekly_salary / 7 if weekly_salary > 0 else 0
    vacation_amount = (
        parse_number(row.get("SUELDO EN EFECTIVO"))
        or parse_number(row.get("VACACIONES EN EFECTIVO"))
        or parse_number(row.get("TOTAL"))
    )
    if vacation_amount <= 0:
        raise RuntimeError(
            f"No se pudo derivar importe vacacional de sem33 para {profile.employee_id} {profile.employee_name}"
        )
    vacation_days = round(vacation_amount / daily_rate, 2) if daily_rate > 0 else 0
    notes_parts = [
        f"sem33.xlsx {period_label}",
        f"Sembrado desde nómina final semanal",
        f"Cheque=VACACIONES",
        f"Importe base {vacation_amount:.2f}",
    ]
    if parse_number(row.get("BONOS Y HORAS EXTRA")) > 0:
        notes_parts.append(f"Extras detectadas {parse_number(row.get('BONOS Y HORAS EXTRA')):.2f}")
    if parse_number(row.get("INFONAVITT")) > 0:
        notes_parts.append(f"Infonavit fiscal {parse_number(row.get('INFONAVITT')):.2f}")
    if parse_number(row.get("FONACOT")) > 0:
        notes_parts.append(f"Fonacot fiscal {parse_number(row.get('FONACOT')):.2f}")
    if parse_number(row.get("DESCUENTO INFONAVITT")) > 0:
        notes_parts.append(
            f"Desc. Infonavit operativo {parse_number(row.get('DESCUENTO INFONAVITT')):.2f}"
        )
    if parse_number(row.get("DESCUENTO PRESTAMO")) > 0:
        notes_parts.append(
            f"Desc. préstamo operativo {parse_number(row.get('DESCUENTO PRESTAMO')):.2f}"
        )
    receipt_group_key = f"{PERIOD_PREFIX}{period_start.isoformat()}|{period_end.isoformat()}|{profile.employee_id}"
    return WeeklyVacationSignal(
        employee_id=profile.employee_id,
        employee_name=profile.employee_name,
        empresa=profile.empresa,
        weekly_salary=weekly_salary,
        daily_rate=daily_rate,
        vacation_amount=vacation_amount,
        vacation_days=vacation_days,
        account_reference=row.get("NO. DE CUENTA", "").strip(),
        receipt_group_key=receipt_group_key,
        period_label=period_label,
        period_start=period_start,
        period_end=period_end,
        notes=" · ".join(notes_parts),
    )


def fetch_profiles() -> dict[str, EmployeeProfile]:
    rows = fetch_all(
        "hr_employee_profiles",
        "id,nombre,empresa,fecha_ingreso,fecha_alta,salario,salario_real_percibido",
    )
    profiles: dict[str, EmployeeProfile] = {}
    for row in rows:
        employee_id = str(row.get("id") or "").strip()
        if not employee_id:
            continue
        profiles[employee_id] = EmployeeProfile(
            employee_id=employee_id,
            employee_name=str(row.get("nombre") or "").strip(),
            empresa=str(row.get("empresa") or "").strip(),
            fecha_ingreso=parse_db_date(row.get("fecha_ingreso")),
            fecha_alta=parse_db_date(row.get("fecha_alta")),
            salario=parse_number(row.get("salario")),
            salario_percibido=parse_number(row.get("salario_real_percibido")),
        )
    return profiles


def fetch_balances(exercise_year: int, employee_ids: list[str]) -> dict[str, VacationBalance]:
    if not employee_ids:
        return {}
    rows = fetch_all(
        "hr_employee_vacation_balances",
        (
            "id,employee_id,exercise_year,base_date_policy,base_fecha_ingreso,base_fecha_alta,"
            "antiguedad_years,entitlement_rule_key,days_entitled,days_paid,days_enjoyed,"
            "days_reserved,days_taken,days_available,salary_snapshot,salary_perceived_snapshot,status"
        ),
        filters={
            "exercise_year": f"eq.{exercise_year}",
            "employee_id": f"in.({','.join(employee_ids)})",
        },
    )
    balances: dict[str, VacationBalance] = {}
    for row in rows:
        employee_id = str(row.get("employee_id") or "").strip()
        balances[employee_id] = VacationBalance(
            id=str(row.get("id") or "").strip(),
            employee_id=employee_id,
            exercise_year=int(row.get("exercise_year") or 0),
            base_date_policy=str(row.get("base_date_policy") or "fecha_ingreso"),
            base_fecha_ingreso=parse_db_date(row.get("base_fecha_ingreso")),
            base_fecha_alta=parse_db_date(row.get("base_fecha_alta")),
            antiguedad_years=int(row.get("antiguedad_years") or 0),
            entitlement_rule_key=str(row.get("entitlement_rule_key") or ""),
            days_entitled=parse_number(row.get("days_entitled")),
            days_paid=parse_number(row.get("days_paid")),
            days_enjoyed=parse_number(row.get("days_enjoyed")),
            days_reserved=parse_number(row.get("days_reserved")),
            days_taken=parse_number(row.get("days_taken")),
            days_available=parse_number(row.get("days_available")),
            salary_snapshot=parse_number(row.get("salary_snapshot")),
            salary_perceived_snapshot=parse_number(row.get("salary_perceived_snapshot")),
            status=str(row.get("status") or "pendiente"),
        )
    return balances


def fetch_events(exercise_year: int, employee_ids: list[str]) -> dict[str, VacationEvent]:
    if not employee_ids:
        return {}
    rows = fetch_all(
        "hr_employee_vacation_events",
        (
            "id,employee_id,exercise_year,receipt_group_key,event_type,start_date,end_date,"
            "days_applied,status,impact_attendance,impact_prenomina,generate_receipt,"
            "attendance_sync_status,prenomina_sync_status,notes"
        ),
        filters={
            "exercise_year": f"eq.{exercise_year}",
            "employee_id": f"in.({','.join(employee_ids)})",
        },
    )
    events: dict[str, VacationEvent] = {}
    for row in rows:
        key = str(row.get("receipt_group_key") or "").strip()
        if not key:
            continue
        events[key] = VacationEvent(
            id=str(row.get("id") or "").strip(),
            employee_id=str(row.get("employee_id") or "").strip(),
            exercise_year=int(row.get("exercise_year") or 0),
            receipt_group_key=key,
            event_type=str(row.get("event_type") or ""),
            start_date=parse_db_date(row.get("start_date")) or date.today(),
            end_date=parse_db_date(row.get("end_date")) or date.today(),
            days_applied=parse_number(row.get("days_applied")),
            status=str(row.get("status") or ""),
            impact_attendance=row.get("impact_attendance") is True,
            impact_prenomina=row.get("impact_prenomina") is True,
            generate_receipt=row.get("generate_receipt") is True,
            attendance_sync_status=str(row.get("attendance_sync_status") or ""),
            prenomina_sync_status=str(row.get("prenomina_sync_status") or ""),
            notes=str(row.get("notes") or ""),
        )
    return events


def fetch_calculations(event_ids: list[str]) -> dict[str, list[dict[str, Any]]]:
    if not event_ids:
        return {}
    rows = fetch_all(
        "hr_employee_vacation_calculations",
        (
            "id,vacation_event_id,sequence_no,component_label,calculation_mode,base_date_policy,"
            "days_paid,daily_salary_used,daily_salary_perceived_used,vacation_pay,"
            "vacation_bonus_rate,vacation_bonus_pay,transfer_component,cash_component,"
            "difference_component,status,is_final,notes"
        ),
        filters={"vacation_event_id": f"in.({','.join(event_ids)})"},
    )
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(str(row.get("vacation_event_id") or "").strip(), []).append(dict(row))
    return grouped


def build_balance_payload(
    profile: EmployeeProfile,
    *,
    exercise_year: int,
    period_end: date,
    existing: VacationBalance | None,
) -> dict[str, Any]:
    base_policy = existing.base_date_policy if existing else "fecha_ingreso"
    base_ingreso = existing.base_fecha_ingreso if existing else profile.fecha_ingreso
    base_alta = existing.base_fecha_alta if existing else profile.fecha_alta
    anchor_date = (
        base_ingreso
        if base_policy == "fecha_ingreso"
        else base_alta
        if base_policy == "fecha_alta"
        else base_ingreso or base_alta
    )
    antiguedad_years = existing.antiguedad_years if existing else years_of_service(anchor_date, period_end)
    rule_key, days_entitled = choose_entitlement_rule_key(antiguedad_years)
    return {
        **({"id": existing.id} if existing else {}),
        "employee_id": profile.employee_id,
        "employee_name": profile.employee_name,
        "empresa": profile.empresa,
        "exercise_year": exercise_year,
        "base_date_policy": base_policy,
        "base_fecha_ingreso": base_ingreso.isoformat() if base_ingreso else None,
        "base_fecha_alta": base_alta.isoformat() if base_alta else None,
        "antiguedad_years": antiguedad_years,
        "entitlement_rule_key": existing.entitlement_rule_key if existing and existing.entitlement_rule_key else rule_key,
        "days_entitled": existing.days_entitled if existing and existing.days_entitled > 0 else days_entitled,
        "days_taken": existing.days_taken if existing else 0,
        "days_available": existing.days_available if existing and existing.days_available > 0 else days_entitled,
        "salary_snapshot": existing.salary_snapshot if existing and existing.salary_snapshot > 0 else profile.salario,
        "salary_perceived_snapshot": (
            existing.salary_perceived_snapshot
            if existing and existing.salary_perceived_snapshot > 0
            else profile.salario_percibido
        ),
        "status": existing.status if existing else "calculado",
        "manual_override": False,
        "manual_override_reason": "",
        "notes": "Semilla base para migración semanal sem33",
    }


def build_event_payload(
    signal: WeeklyVacationSignal,
    *,
    exercise_year: int,
    balance_id: str | None,
    existing_event_id: str | None,
) -> dict[str, Any]:
    return {
        **({"id": existing_event_id} if existing_event_id else {}),
        "balance_id": balance_id,
        "employee_id": signal.employee_id,
        "employee_name": signal.employee_name,
        "exercise_year": exercise_year,
        "event_type": "vacaciones_pagadas",
        "start_date": signal.period_end.isoformat(),
        "end_date": signal.period_end.isoformat(),
        "days_applied": signal.vacation_days,
        "attendance_period_label": "",
        "attendance_sync_status": "omitido",
        "prenomina_sync_status": "aplicado",
        "impact_attendance": False,
        "impact_prenomina": True,
        "generate_receipt": True,
        "receipt_group_key": signal.receipt_group_key,
        "status": "aplicado",
        "notes": signal.notes,
    }


def build_calculation_payload(
    signal: WeeklyVacationSignal,
    *,
    exercise_year: int,
    event_id: str,
    base_date_policy: str,
    existing_calc_id: str | None,
) -> dict[str, Any]:
    return {
        **({"id": existing_calc_id} if existing_calc_id else {}),
        "vacation_event_id": event_id,
        "employee_id": signal.employee_id,
        "exercise_year": exercise_year,
        "sequence_no": 1,
        "component_label": "Migración sem33 vacaciones",
        "calculation_mode": "manual_rh",
        "base_date_policy": base_date_policy,
        "days_paid": signal.vacation_days,
        "daily_salary_used": round(signal.daily_rate, 2),
        "daily_salary_perceived_used": 0,
        "vacation_pay": round(signal.vacation_amount, 2),
        "vacation_bonus_rate": 0,
        "vacation_bonus_pay": 0,
        "transfer_component": 0,
        "cash_component": round(signal.vacation_amount, 2),
        "difference_component": 0,
        "status": "vigente",
        "is_final": True,
        "notes": signal.notes,
    }


def recalc_balance_patch(balance_id: str, balance: VacationBalance, events: list[VacationEvent]) -> dict[str, Any]:
    days_paid = 0.0
    days_enjoyed = 0.0
    days_reserved = 0.0
    for event in events:
        if event.status == "aplicado" and (
            event.event_type == "vacaciones_pagadas"
            or event.impact_prenomina
            or event.generate_receipt
        ):
            days_paid += event.days_applied
        if event.status == "aplicado" and (
            event.event_type == "vacaciones_disfrutadas" or event.impact_attendance
        ):
            days_enjoyed += event.days_applied
        if event.status not in {"aplicado", "cancelado"} and (
            event.event_type in {"vacaciones_pendientes", "vacaciones_disfrutadas", "ajuste_rh"}
            or event.impact_attendance
        ):
            days_reserved += event.days_applied
    days_taken = max(days_enjoyed + days_reserved, 0)
    days_available = max(balance.days_entitled - (days_enjoyed + days_reserved), 0)
    return {
        "id": balance_id,
        "days_paid": round(days_paid, 2),
        "days_enjoyed": round(days_enjoyed, 2),
        "days_reserved": round(days_reserved, 2),
        "days_taken": round(days_taken, 2),
        "days_available": round(days_available, 2),
        "status": "aplicado" if days_paid > 0 else balance.status,
    }


def main() -> int:
    args = parse_args()
    workbook_path = Path(args.workbook).expanduser().resolve()
    if not workbook_path.exists():
        raise SystemExit(f"No existe el archivo: {workbook_path}")

    period_label, period_start, period_end, sem_rows = parse_sem33_vacation_signals(workbook_path)
    profiles = fetch_profiles()
    exercise_year = period_end.year

    signals: list[WeeklyVacationSignal] = []
    missing_profiles: list[str] = []
    for row in sem_rows:
        employee_id = str(row.get("NO.", "")).strip()
        profile = profiles.get(employee_id)
        if profile is None:
            missing_profiles.append(employee_id)
            continue
        signals.append(
            build_signal(
                row,
                period_label=period_label,
                period_start=period_start,
                period_end=period_end,
                profile=profile,
            )
        )

    if missing_profiles:
        raise SystemExit(
            "No se encontraron perfiles en hr_employee_profiles para: "
            + ", ".join(sorted(missing_profiles))
        )

    employee_ids = sorted({signal.employee_id for signal in signals})
    balances = fetch_balances(exercise_year, employee_ids)
    existing_events = fetch_events(exercise_year, employee_ids)

    balance_payloads = [
        build_balance_payload(
            profiles[employee_id],
            exercise_year=exercise_year,
            period_end=period_end,
            existing=balances.get(employee_id),
        )
        for employee_id in employee_ids
    ]

    print(f"Periodo detectado: {period_label}")
    print(f"Vacaciones detectadas en sem33: {len(signals)}")
    for signal in signals:
        print(
            f"- {signal.employee_id} {signal.employee_name}: "
            f"{signal.vacation_days:.2f} día(s) | "
            f"${signal.vacation_amount:,.2f} | "
            f"{signal.account_reference or 'sin cuenta'}"
        )

    if not args.apply:
        print("\nDry-run: no se aplicaron cambios.")
        return 0

    upserted_balances = upsert_rows(
        "hr_employee_vacation_balances",
        balance_payloads,
        on_conflict="employee_id,exercise_year",
    )
    balance_map = {
        str(row.get("employee_id") or "").strip(): str(row.get("id") or "").strip()
        for row in upserted_balances
    }

    event_payloads: list[dict[str, Any]] = []
    for signal in signals:
        existing_event = existing_events.get(signal.receipt_group_key)
        event_payloads.append(
            build_event_payload(
                signal,
                exercise_year=exercise_year,
                balance_id=balance_map.get(signal.employee_id) or balances.get(signal.employee_id, VacationBalance(
                    id="",
                    employee_id=signal.employee_id,
                    exercise_year=exercise_year,
                    base_date_policy="fecha_ingreso",
                    base_fecha_ingreso=None,
                    base_fecha_alta=None,
                    antiguedad_years=0,
                    entitlement_rule_key="",
                    days_entitled=0,
                    days_paid=0,
                    days_enjoyed=0,
                    days_reserved=0,
                    days_taken=0,
                    days_available=0,
                    salary_snapshot=0,
                    salary_perceived_snapshot=0,
                    status="pendiente",
                )).id
                or None,
                existing_event_id=existing_event.id if existing_event else None,
            )
        )

    applied_events: list[dict[str, Any]] = []
    for payload in event_payloads:
        if payload.get("id"):
            event_id = str(payload["id"])
            patch = dict(payload)
            patch.pop("id", None)
            rows = patch_rows("hr_employee_vacation_events", {"id": f"eq.{event_id}"}, patch)
            applied_events.extend(rows)
        else:
            rows = post_rows("hr_employee_vacation_events", [payload])
            applied_events.extend(rows)

    event_ids = [str(row.get("id") or "").strip() for row in applied_events]
    calculation_rows = fetch_calculations(event_ids)
    calculation_payloads: list[dict[str, Any]] = []
    for signal in signals:
        event_row = next(
            row for row in applied_events if str(row.get("receipt_group_key") or "") == signal.receipt_group_key
        )
        event_id = str(event_row.get("id") or "").strip()
        existing_calc = None
        for row in calculation_rows.get(event_id, []):
            if int(row.get("sequence_no") or 0) == 1:
                existing_calc = row
                break
        balance_payload = next(item for item in balance_payloads if item["employee_id"] == signal.employee_id)
        calculation_payloads.append(
            build_calculation_payload(
                signal,
                exercise_year=exercise_year,
                event_id=event_id,
                base_date_policy=str(balance_payload.get("base_date_policy") or "fecha_ingreso"),
                existing_calc_id=str(existing_calc.get("id") or "").strip() if existing_calc else None,
            )
        )

    for payload in calculation_payloads:
        if payload.get("id"):
            calc_id = str(payload["id"])
            patch = dict(payload)
            patch.pop("id", None)
            patch_rows("hr_employee_vacation_calculations", {"id": f"eq.{calc_id}"}, patch)
        else:
            post_rows("hr_employee_vacation_calculations", [payload])

    refreshed_events = fetch_events(exercise_year, employee_ids)
    balance_rows_after = fetch_balances(exercise_year, employee_ids)
    balance_patches = []
    for employee_id in employee_ids:
        balance = balance_rows_after.get(employee_id)
        if balance is None:
            continue
        employee_events = [
            event
            for event in refreshed_events.values()
            if event.employee_id == employee_id and event.exercise_year == exercise_year
        ]
        balance_patches.append(recalc_balance_patch(balance.id, balance, employee_events))
    upsert_rows(
        "hr_employee_vacation_balances",
        balance_patches,
        on_conflict="id",
    )

    print("\nAplicado en Supabase:")
    for signal in signals:
        print(
            f"- {signal.employee_id} {signal.employee_name}: "
            f"{signal.vacation_days:.2f} día(s) sembrados en Vacaciones"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
