#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from pathlib import Path

NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}
MONTHS_ES = {
    "enero": 1,
    "febrero": 2,
    "marzo": 3,
    "abril": 4,
    "mayo": 5,
    "junio": 6,
    "julio": 7,
    "agosto": 8,
    "septiembre": 9,
    "setiembre": 9,
    "octubre": 10,
    "noviembre": 11,
    "diciembre": 12,
}


def _escape_sql(value: str) -> str:
    return value.replace("'", "''")


def _read_shared_strings(zf: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zf.namelist():
        return []
    root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
    values: list[str] = []
    for item in root:
        text = "".join(
            node.text or ""
            for node in item.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")
        )
        values.append(text)
    return values


def _read_sheet_rows(zf: zipfile.ZipFile, shared_strings: list[str], target: str):
    root = ET.fromstring(zf.read(target))
    rows = root.find("a:sheetData", NS)
    result: list[tuple[int, dict[str, str]]] = []
    if rows is None:
        return result
    for row in rows:
        row_number = int(row.attrib["r"])
        values: dict[str, str] = {}
        for cell in row:
            ref = cell.attrib.get("r", "")
            col = re.match(r"[A-Z]+", ref).group(0)
            cell_type = cell.attrib.get("t")
            value_node = cell.find("a:v", NS)
            value = ""
            if value_node is not None:
                value = value_node.text or ""
                if cell_type == "s" and value:
                    value = shared_strings[int(value)]
            values[col] = value
        result.append((row_number, values))
    return result


def _xlsx_date_to_iso(raw: str) -> str:
    raw = (raw or "").strip()
    if not raw:
        return ""
    try:
        serial = float(raw)
    except ValueError:
        match = re.match(r"^(\d{1,2})\s+de\s+([a-zA-ZáéíóúñÑ]+)\s+de\s+(\d{4})$", raw, re.IGNORECASE)
        if match:
            day = int(match.group(1))
            month_name = match.group(2).lower()
            month_name = (
                month_name.replace("á", "a")
                .replace("é", "e")
                .replace("í", "i")
                .replace("ó", "o")
                .replace("ú", "u")
            )
            month = MONTHS_ES.get(month_name)
            year = int(match.group(3))
            if month is not None:
                return datetime(year, month, day).strftime("%Y-%m-%d")
        return raw
    base = datetime(1899, 12, 30)
    return (base + timedelta(days=serial)).strftime("%Y-%m-%d")


def _normalize_account(raw: str) -> str:
    value = (raw or "").strip()
    value = value.replace("No. CTA.", "").replace("No. de cuenta", "").strip()
    return value


def _normalize_company(raw: str) -> str:
    value = (raw or "").strip()
    if not value:
        return "DICSA CELAYA"
    upper = value.upper()
    if upper == "WHIRPOOL":
        return "WHIRLPOOL"
    administrative_notes = {
        "NO SE PAGA TIEMPO EXTRA",
        "2 SABADOS",
        "500 DE AVON",
    }
    if upper in administrative_notes:
        return "DICSA CELAYA"
    return value


def _normalize_identifier(raw: str) -> str:
    return (raw or "").strip()


def _parse_personnel_rows(xlsx_path: Path) -> list[dict[str, str]]:
    with zipfile.ZipFile(xlsx_path) as zf:
        shared_strings = _read_shared_strings(zf)
        lista_rows = _read_sheet_rows(zf, shared_strings, "xl/worksheets/sheet1.xml")
        sem_rows = _read_sheet_rows(zf, shared_strings, "xl/worksheets/sheet4.xml")

    employees: dict[str, dict[str, str]] = {}

    for row_number, values in lista_rows:
        if row_number < 8:
            continue
        employee_id = _normalize_identifier(values.get("A", ""))
        employee_name = values.get("B", "").strip()
        if not employee_id or not employee_name:
            continue
        employees[employee_id] = {
            "id": employee_id,
            "nombre": employee_name,
            "empresa": "",
            "horario": "",
            "nss": values.get("C", "").strip(),
            "rfc": values.get("D", "").strip().replace(" ", ""),
            "curp": values.get("E", "").strip().replace(" ", ""),
            "fecha_ingreso": _xlsx_date_to_iso(values.get("F", "")),
            "telefono": values.get("G", "").strip(),
            "numero_cuenta": values.get("H", "").strip(),
            "calzado": "",
        }

    current_company = ""
    for row_number, values in sem_rows:
        if row_number < 11:
            continue
        employee_id = _normalize_identifier(values.get("E", ""))
        employee_name = values.get("F", "").strip()
        if not employee_id or not employee_name:
            continue

        company = values.get("B", "").strip()
        if company:
            current_company = company
        else:
            company = current_company

        account = _normalize_account(values.get("T", ""))
        shoe_size = values.get("D", "").strip().replace("#", "")

        employee = employees.setdefault(
            employee_id,
            {
                "id": employee_id,
                "nombre": employee_name,
                "empresa": "",
                "horario": "",
                "nss": "",
                "rfc": "",
                "curp": "",
                "fecha_ingreso": "",
                "telefono": "",
                "numero_cuenta": "",
                "calzado": "",
            },
        )
        employee["empresa"] = _normalize_company(company)
        if account:
            employee["numero_cuenta"] = account
        if shoe_size:
            employee["calzado"] = shoe_size

    for employee in employees.values():
        employee["empresa"] = _normalize_company(employee["empresa"])

    def sort_key(item: dict[str, str]):
        raw = item["id"]
        match = re.sub(r"\D", "", raw)
        return (0, int(match)) if match else (1, raw)

    return sorted(employees.values(), key=sort_key)


def _build_seed_sql(rows: list[dict[str, str]], source_label: str) -> str:
    lines: list[str] = []
    lines.append(f"-- Seed generado desde {source_label}")
    lines.append("-- Fuente: LISTA DE EMPLEADOS + SEM 26")
    lines.append("-- Notas:")
    lines.append("-- - horario no viene poblado en el Excel fuente; se carga vacio")
    lines.append("-- - empresa se hereda por bloque desde SEM 26 cuando la fila viene en blanco")
    lines.append("")
    lines.append("insert into public.hr_employee_profiles (")
    lines.append("  id,")
    lines.append("  nombre,")
    lines.append("  empresa,")
    lines.append("  horario,")
    lines.append("  nss,")
    lines.append("  rfc,")
    lines.append("  curp,")
    lines.append("  fecha_ingreso,")
    lines.append("  telefono,")
    lines.append("  numero_cuenta,")
    lines.append("  calzado")
    lines.append(")")
    lines.append("values")
    value_lines: list[str] = []
    for row in rows:
        fecha = row["fecha_ingreso"] or "2000-01-01"
        value_lines.append(
            "  ("
            f"'{_escape_sql(row['id'])}', "
            f"'{_escape_sql(row['nombre'])}', "
            f"'{_escape_sql(row['empresa'])}', "
            f"'{_escape_sql(row['horario'])}', "
            f"'{_escape_sql(row['nss'])}', "
            f"'{_escape_sql(row['rfc'])}', "
            f"'{_escape_sql(row['curp'])}', "
            f"'{_escape_sql(fecha)}', "
            f"'{_escape_sql(row['telefono'])}', "
            f"'{_escape_sql(row['numero_cuenta'])}', "
            f"'{_escape_sql(row['calzado'])}'"
            ")"
        )
    lines.append(",\n".join(value_lines))
    lines.append("on conflict (id) do update set")
    lines.append("  nombre = excluded.nombre,")
    lines.append("  empresa = excluded.empresa,")
    lines.append("  horario = excluded.horario,")
    lines.append("  nss = excluded.nss,")
    lines.append("  rfc = excluded.rfc,")
    lines.append("  curp = excluded.curp,")
    lines.append("  fecha_ingreso = excluded.fecha_ingreso,")
    lines.append("  telefono = excluded.telefono,")
    lines.append("  numero_cuenta = excluded.numero_cuenta,")
    lines.append("  calzado = excluded.calzado;")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Genera seed SQL de Personal RH desde Semana 26.xlsx",
    )
    parser.add_argument("xlsx_path", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        help="Ruta opcional para escribir el SQL. Si se omite, imprime a stdout.",
    )
    args = parser.parse_args()

    rows = _parse_personnel_rows(args.xlsx_path)
    sql = _build_seed_sql(rows, args.xlsx_path.name)
    if args.output:
      args.output.write_text(sql, encoding="utf-8")
      print(f"SQL generado en {args.output}")
    else:
      sys.stdout.write(sql)
    print(
        f"-- resumen: {len(rows)} empleados; "
        f"{sum(1 for row in rows if not row['empresa'])} sin empresa; "
        f"{sum(1 for row in rows if not row['horario'])} sin horario",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
