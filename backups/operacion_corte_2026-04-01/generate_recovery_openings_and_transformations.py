#!/usr/bin/env python3
"""
Genera un SQL de recuperacion desde el backup del corte 2026-04-01.

Estrategia:
- Usa el snapshot final del 2026-03-31 como verdad de saldos.
- Para cada material general objetivo:
  - crea una apertura GENERAL con:
      general_on_hand_kg + suma(commercial_on_hand_kg)
  - crea transformaciones sinteticas por cada saldo comercial no-cero
    para reconstruir el patio clasificado vivo sin duplicar inventario.

Resultado:
- El saldo final esperado despues de ejecutar el SQL queda igual al snapshot.
- Evitamos reinyectar todo el historico de movimientos/transforms.
"""

from __future__ import annotations

import csv
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


BASE = Path(__file__).resolve().parent
GENERAL_SNAPSHOT = BASE / "snapshot_v_inventory_general_balance_v2.csv"
COMMERCIAL_SNAPSHOT = BASE / "snapshot_v_inventory_commercial_balance_v2.csv"
GENERAL_CATALOG = BASE / "material_general_catalog_v2.csv"
COMMERCIAL_CATALOG = BASE / "material_commercial_catalog_v2.csv"
OUTPUT_SQL = BASE / "recovery_openings_transformations_2026-04-01.sql"
OUTPUT_SUMMARY = BASE / "recovery_openings_transformations_2026-04-01.md"

TARGET_GENERAL_CODES = ("CHATARRA", "METAL", "PAPEL")
PERIOD_MONTH = "2026-04-01"
AS_OF_DATE = "2026-04-01"
SITE = "DICSA_CELAYA"
SHIFT = "DAY"
NOTES = "RECUPERACION DESDE BACKUP CORTE 2026-03-31"


@dataclass
class GeneralBalance:
    id: str
    code: str
    name: str
    on_hand_kg: float


@dataclass
class CommercialBalance:
    id: str
    code: str
    name: str
    general_code: str
    on_hand_kg: float


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def _q(text: str) -> str:
    return "'" + text.replace("'", "''") + "'"


def _fmt_num(value: float) -> str:
    return f"{value:.3f}"


def _load_general_balances() -> dict[str, GeneralBalance]:
    rows = _read_csv(GENERAL_SNAPSHOT)
    result: dict[str, GeneralBalance] = {}
    for row in rows:
        code = (row["code"] or "").strip().upper()
        if code not in TARGET_GENERAL_CODES:
            continue
        result[code] = GeneralBalance(
            id=row["id"],
            code=code,
            name=row["name"],
            on_hand_kg=float(row["on_hand_kg"] or 0),
        )
    return result


def _load_commercial_balances() -> dict[str, list[CommercialBalance]]:
    rows = _read_csv(COMMERCIAL_SNAPSHOT)
    grouped: dict[str, list[CommercialBalance]] = defaultdict(list)
    for row in rows:
        general_code = (row["general_code"] or "").strip().upper()
        if general_code not in TARGET_GENERAL_CODES:
            continue
        on_hand = float(row["on_hand_kg"] or 0)
        if abs(on_hand) < 0.0005:
            continue
        grouped[general_code].append(
            CommercialBalance(
                id=row["id"],
                code=row["code"],
                name=row["name"],
                general_code=general_code,
                on_hand_kg=on_hand,
            )
        )
    for values in grouped.values():
        values.sort(key=lambda item: (-item.on_hand_kg, item.code))
    return grouped


def _sum_on_hand(rows: Iterable[CommercialBalance]) -> float:
    return sum(row.on_hand_kg for row in rows)


def generate() -> tuple[str, str]:
    generals = _load_general_balances()
    commercials = _load_commercial_balances()

    sql_lines: list[str] = []
    summary_lines: list[str] = []

    sql_lines.append("-- Generado automaticamente desde backup de corte")
    sql_lines.append("-- Estrategia: apertura general + transformaciones sinteticas")
    sql_lines.append("begin;")
    sql_lines.append("")

    summary_lines.append("# Recovery Preview 2026-04-01")
    summary_lines.append("")
    summary_lines.append(
        "Reconstruccion sugerida: `apertura general + transformaciones sinteticas`."
    )
    summary_lines.append("")

    for code in TARGET_GENERAL_CODES:
        general = generals[code]
        comm_rows = commercials.get(code, [])
        commercial_total = _sum_on_hand(comm_rows)
        opening_general = general.on_hand_kg + commercial_total

        summary_lines.append(f"## {code}")
        summary_lines.append("")
        summary_lines.append(f"- Saldo general visible al corte: `{_fmt_num(general.on_hand_kg)} kg`")
        summary_lines.append(f"- Saldo comercial vivo al corte: `{_fmt_num(commercial_total)} kg`")
        summary_lines.append(
            f"- Apertura general sugerida: `{_fmt_num(opening_general)} kg`"
        )
        if comm_rows:
            summary_lines.append("- Transformaciones sinteticas sugeridas:")
            for row in comm_rows:
                summary_lines.append(
                    f"  - `{row.code}`: `{_fmt_num(row.on_hand_kg)} kg`"
                )
        else:
            summary_lines.append("- No requiere transformaciones sinteticas.")
        summary_lines.append("")

        sql_lines.append(f"-- {code}")
        sql_lines.append(
            "insert into public.inventory_opening_balances_v2 ("
            "period_month, as_of_date, inventory_level, general_material_id, weight_kg, unit_count, site, notes"
            ") values ("
            f"{_q(PERIOD_MONTH)}, {_q(AS_OF_DATE)}, 'GENERAL', {_q(general.id)}, "
            f"{_fmt_num(opening_general)}, null, {_q(SITE)}, "
            f"{_q(f'{NOTES} | APERTURA GENERAL {code}')}"
            ");"
        )
        sql_lines.append("")

        for idx, row in enumerate(comm_rows, start=1):
            run_note = f"{NOTES} | TRANSFORMACION SINTETICA {code}->{row.code}"
            sql_lines.append("with inserted_run as (")
            sql_lines.append(
                "  insert into public.material_transformation_runs_v2 ("
                "op_date, shift, source_general_material_id, input_weight_kg, site, notes"
                ") values ("
                f"{_q(AS_OF_DATE)}, {_q(SHIFT)}, {_q(general.id)}, {_fmt_num(row.on_hand_kg)}, {_q(SITE)}, {_q(run_note)}"
                ")"
            )
            sql_lines.append("  returning id")
            sql_lines.append(")")
            sql_lines.append(
                "insert into public.material_transformation_run_outputs_v2 ("
                "run_id, commercial_material_id, output_weight_kg, output_unit_count, notes"
                ")"
            )
            sql_lines.append(
                "select id, "
                f"{_q(row.id)}, {_fmt_num(row.on_hand_kg)}, null, {_q(run_note)} "
                "from inserted_run;"
            )
            sql_lines.append("")

    sql_lines.append("commit;")
    sql_lines.append("")

    return "\n".join(sql_lines), "\n".join(summary_lines)


def main() -> None:
    sql_text, summary_text = generate()
    OUTPUT_SQL.write_text(sql_text, encoding="utf-8")
    OUTPUT_SUMMARY.write_text(summary_text, encoding="utf-8")
    print(f"wrote {OUTPUT_SQL}")
    print(f"wrote {OUTPUT_SUMMARY}")


if __name__ == "__main__":
    main()
