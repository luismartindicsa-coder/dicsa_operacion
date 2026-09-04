#!/usr/bin/env python3
"""Read-only reconciliation of possible internal cash transfers."""

from __future__ import annotations

import json
import plistlib
import sys
from datetime import date
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

SUPABASE_URL = 'https://pjxncveymixxdntplchb.supabase.co'
SUPABASE_ANON_KEY = 'sb_publishable_0CPL9An-gAReMKpoDYhMtg_Da6Lc3qb'
AUTH_PREFS = Path.home() / (
    'Library/Containers/com.example.dicsaOperacion/Data/Library/Preferences/'
    'com.example.dicsaOperacion.plist'
)


def normalize(value: object) -> str:
    return str(value or '').upper().translate(
        str.maketrans('ÁÉÍÓÚÜÑ', 'AEIOUUN')
    ).strip()


def auth_token() -> str:
    with AUTH_PREFS.open('rb') as handle:
        payload = plistlib.load(handle)
    session = json.loads(payload['flutter.sb-pjxncveymixxdntplchb-auth-token'])
    return str(session['access_token'])


def fetch(table: str, select: str) -> list[dict]:
    query = urlencode({'select': select, 'order': 'id'})
    request = Request(
        f'{SUPABASE_URL}/rest/v1/{table}?{query}',
        headers={
            'apikey': SUPABASE_ANON_KEY,
            'Authorization': f'Bearer {auth_token()}',
        },
    )
    with urlopen(request) as response:
        return json.loads(response.read().decode('utf-8'))


def movement_date(row: dict, key: str) -> date:
    return date.fromisoformat(str(row[key])[:10])


def is_explicit_internal(row: dict) -> bool:
    return normalize(row.get('category') or row.get('rubric')) in {
        'MOVIMIENTOS INTERNOS',
        'REPOSICION DE FONDO',
    }


def candidates(bank: list[dict], target: list[dict], target_date: str) -> list[dict]:
    result: list[dict] = []
    for debit in bank:
        amount = float(debit.get('debit_amount') or 0)
        if amount <= 0.009 or is_explicit_internal(debit):
            continue
        debit_date = movement_date(debit, 'movement_date')
        for deposit in target:
            target_amount = float(deposit.get('total_amount') or 0)
            if target_amount <= 0.009 or is_explicit_internal(deposit):
                continue
            if abs(amount - target_amount) > 0.009:
                continue
            days = abs((movement_date(deposit, target_date) - debit_date).days)
            if days > 3:
                continue
            text = normalize(
                f"{debit.get('comment', '')} {debit.get('reference', '')} "
                f"{debit.get('counterparty_name_snapshot', '')}"
            )
            result.append(
                {
                    'bank_id': debit['id'],
                    'target_id': deposit['id'],
                    'amount': amount,
                    'date_gap_days': days,
                    'bank_category': debit.get('category'),
                    'bank_comment': debit.get('comment'),
                    'bank_reference': debit.get('reference'),
                    'bank_counterparty': debit.get('counterparty_name_snapshot'),
                    'target_rubric': deposit.get('rubric'),
                    'target_comment': deposit.get('comment'),
                    'target_person': deposit.get('person_label'),
                    'target_folio': deposit.get('folio'),
                    'has_cash_destination_hint': any(
                        token in text
                        for token in ('BOVEDA', 'CAJA', 'MENUDEO', 'TRASPASO', 'REPOSICION')
                    ),
                }
            )
    return result


def main() -> int:
    bank = fetch(
        'finanzas_bank_movements',
        'id,movement_date,category,comment,reference,counterparty_name_snapshot,credit_amount,debit_amount',
    )
    vault = fetch(
        'direction_vault_vouchers',
        'id,voucher_date,folio,voucher_type,person_label,rubric,comment,total_amount',
    )
    cash = fetch(
        'vw_men_cash_vouchers_grid',
        'id,voucher_date,voucher_type,person_label,rubric,total_amount',
    )
    vault_deposits = [row for row in vault if row.get('voucher_type') == 'deposit']
    cash_deposits = [row for row in cash if row.get('voucher_type') == 'deposit']
    report = {
        'bank_movements': len(bank),
        'vault_vouchers': len(vault),
        'menudeo_vouchers': len(cash),
        'explicit_internal_bank': sum(is_explicit_internal(row) for row in bank),
        'explicit_internal_vault': sum(is_explicit_internal(row) for row in vault),
        'explicit_internal_menudeo': sum(is_explicit_internal(row) for row in cash),
        'bank_to_vault_candidates': candidates(bank, vault_deposits, 'voucher_date'),
        'bank_to_menudeo_candidates': candidates(bank, cash_deposits, 'voucher_date'),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
