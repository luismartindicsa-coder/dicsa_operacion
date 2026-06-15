from __future__ import annotations

import csv
import json
import plistlib
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

SUPABASE_URL = 'https://pjxncveymixxdntplchb.supabase.co'
SUPABASE_ANON_KEY = 'sb_publishable_0CPL9An-gAReMKpoDYhMtg_Da6Lc3qb'
SHARED_PREFS_PATHS = [
    Path.home() / 'Library/Containers/com.example.dicsaOperacion/Data/Library/Preferences/com.example.dicsaOperacion.plist',
    Path.home() / 'Library/Containers/DICSA.dicsa-operacion/Data/Library/Preferences/DICSA.dicsa-operacion.plist',
]

ROOT = Path(__file__).resolve().parents[1]
OUT_CSV = ROOT / 'docs' / 'migrations' / 'finanzas_company_identity_audit.csv'
OUT_JSON = ROOT / 'docs' / 'migrations' / 'finanzas_company_identity_audit.json'


def normalize(value: str) -> str:
    text = (value or '').strip().upper()
    for src, dst in (
        ('Á', 'A'),
        ('É', 'E'),
        ('Í', 'I'),
        ('Ó', 'O'),
        ('Ú', 'U'),
        ('Ü', 'U'),
        ('Ñ', 'N'),
    ):
        text = text.replace(src, dst)
    text = re.sub(r'[^A-Z0-9]+', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


def fetch_all(table: str, select: str, order: str | None = None) -> list[dict]:
    rows: list[dict] = []
    offset = 0
    page_size = 1000
    while True:
        params = {
            'select': select,
            'limit': str(page_size),
            'offset': str(offset),
        }
        if order:
            params['order'] = order
        url = f'{SUPABASE_URL}/rest/v1/{table}?{urlencode(params)}'
        try:
            req = Request(
                url,
                headers={
                    'apikey': SUPABASE_ANON_KEY,
                    'Authorization': f'Bearer {resolve_supabase_bearer_token()}',
                },
            )
            with urlopen(req) as response:
                payload = json.loads(response.read().decode('utf-8'))
        except Exception:
            payload = json.loads(
                subprocess.check_output(
                    [
                        'curl',
                        '-s',
                        url,
                        '-H',
                        f'apikey: {SUPABASE_ANON_KEY}',
                        '-H',
                        f'Authorization: Bearer {resolve_supabase_bearer_token()}',
                    ],
                    text=True,
                )
            )
        if not payload:
            break
        rows.extend(dict(row) for row in payload)
        if len(payload) < page_size:
            break
        offset += page_size
    return rows


def resolve_supabase_bearer_token() -> str:
    for path in SHARED_PREFS_PATHS:
        if not path.exists():
            continue
        try:
            with path.open('rb') as fh:
                payload = plistlib.load(fh)
            raw = payload.get('flutter.sb-pjxncveymixxdntplchb-auth-token')
            if not raw:
                continue
            session = json.loads(raw)
            token = str(session.get('access_token') or '').strip()
            if token:
                return token
        except Exception:
            continue
    return SUPABASE_ANON_KEY


def build_name_index(rows: list[dict], id_key: str = 'id', name_key: str = 'name') -> dict[str, list[dict]]:
    index: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        key = normalize(str(row.get(name_key) or ''))
        if key:
            index[key].append(row)
    return index


def main() -> int:
    fin_companies = fetch_all(
        'finanzas_catalog_companies',
        'id,name,source,linked_name,is_active,notes',
        'name.asc',
    )
    compras_companies = fetch_all(
        'compras_counterparties',
        'id,name,is_active,notes',
        'name.asc',
    )
    ventas_companies = fetch_all(
        'mayoreo_counterparties',
        'id,name,is_active,notes',
        'name.asc',
    )
    invoices = fetch_all(
        'finanzas_supplier_invoices',
        'id,provider_id,provider_name_snapshot,invoice_folio,total_amount,balance_amount,status',
        'invoice_date.desc',
    )
    bank_movements = fetch_all(
        'finanzas_bank_movements',
        'id,counterparty_company_id,counterparty_name_snapshot,source_type,linked_supplier_invoice_id,linked_external_ref,credit_amount,debit_amount',
        'movement_date.desc',
    )

    fin_by_name = build_name_index(fin_companies)
    compras_by_name = build_name_index(compras_companies)
    ventas_by_name = build_name_index(ventas_companies)
    fin_by_id = {str(row.get('id') or ''): row for row in fin_companies}

    issues: list[dict[str, str]] = []

    def add_issue(issue_type: str, severity: str, scope: str, company_name: str, details: str, refs: str) -> None:
        issues.append(
            {
                'issue_type': issue_type,
                'severity': severity,
                'scope': scope,
                'company_name': company_name,
                'details': details,
                'refs': refs,
            }
        )

    all_names = sorted(set(fin_by_name) | set(compras_by_name) | set(ventas_by_name))
    for key in all_names:
        fin_rows = fin_by_name.get(key, [])
        compras_rows = compras_by_name.get(key, [])
        ventas_rows = ventas_by_name.get(key, [])
        human_name = (
            (fin_rows[0].get('name') if fin_rows else None)
            or (compras_rows[0].get('name') if compras_rows else None)
            or (ventas_rows[0].get('name') if ventas_rows else None)
            or key
        )

        if len(fin_rows) > 1:
            add_issue(
                'FIN_DUPLICATE_NAME',
                'critical',
                'Finanzas',
                str(human_name),
                f'Hay {len(fin_rows)} empresas en Finanzas con el mismo nombre normalizado.',
                ','.join(str(row.get('id') or '') for row in fin_rows),
            )

        if compras_rows and ventas_rows:
            add_issue(
                'CROSS_SOURCE_ALIAS',
                'high',
                'Compras Mayoreo + Ventas Mayoreo',
                str(human_name),
                'El mismo nombre existe en Compras Mayoreo y Ventas Mayoreo; requiere criterio canónico en Finanzas.',
                'compras=' + ','.join(str(row.get('id') or '') for row in compras_rows)
                + ' | ventas=' + ','.join(str(row.get('id') or '') for row in ventas_rows),
            )

        if fin_rows:
            fin_row = fin_rows[0]
            fin_source = str(fin_row.get('source') or '')
            fin_id = str(fin_row.get('id') or '')
            if fin_source == 'COMPRAS' and not compras_rows:
                add_issue(
                    'FIN_SOURCE_WITHOUT_COMPRAS_MATCH',
                    'high',
                    'Finanzas',
                    str(human_name),
                    'Empresa marcada como COMPRAS en Finanzas pero ya no existe en Compras Mayoreo por nombre.',
                    fin_id,
                )
            if fin_source == 'VENTAS' and not ventas_rows:
                add_issue(
                    'FIN_SOURCE_WITHOUT_VENTAS_MATCH',
                    'high',
                    'Finanzas',
                    str(human_name),
                    'Empresa marcada como VENTAS en Finanzas pero ya no existe en Ventas Mayoreo por nombre.',
                    fin_id,
                )
            if fin_source == 'DIRECTO' and (compras_rows or ventas_rows):
                add_issue(
                    'DIRECTO_SHADOWS_EXTERNAL',
                    'medium',
                    'Finanzas',
                    str(human_name),
                    'Empresa DIRECTO en Finanzas comparte nombre con empresa externa; revisar si debe consolidarse.',
                    fin_id,
                )

    for invoice in invoices:
        provider_id = str(invoice.get('provider_id') or '')
        provider_name = str(invoice.get('provider_name_snapshot') or '').strip()
        normalized_name = normalize(provider_name)
        fin_company = fin_by_id.get(provider_id)
        if fin_company is None:
            add_issue(
                'INVOICE_ORPHAN_PROVIDER_ID',
                'critical',
                'Facturas proveedor',
                provider_name or provider_id,
                'La factura referencia un provider_id inexistente en finanzas_catalog_companies.',
                f"invoice={invoice.get('id')},provider_id={provider_id}",
            )
            continue

        fin_name = str(fin_company.get('name') or '').strip()
        if normalized_name and normalize(fin_name) != normalized_name:
            add_issue(
                'INVOICE_NAME_MISMATCH',
                'high',
                'Facturas proveedor',
                provider_name or fin_name,
                'provider_name_snapshot no coincide con el nombre de la empresa ligada en Finanzas.',
                f"invoice={invoice.get('id')},provider_id={provider_id},fin_name={fin_name}",
            )

        compras_rows = compras_by_name.get(normalized_name, [])
        ventas_rows = ventas_by_name.get(normalized_name, [])
        fin_source = str(fin_company.get('source') or '')
        if compras_rows and ventas_rows:
            add_issue(
                'INVOICE_AMBIGUOUS_ALIAS',
                'medium',
                'Facturas proveedor',
                provider_name or fin_name,
                'La factura usa un nombre que existe en Compras Mayoreo y Ventas Mayoreo; revisar que el provider_id canónico sea el correcto.',
                f"invoice={invoice.get('id')},provider_id={provider_id},source={fin_source}",
            )

    for movement in bank_movements:
        counterparty_id = str(movement.get('counterparty_company_id') or '').strip()
        counterparty_name = str(movement.get('counterparty_name_snapshot') or '').strip()
        normalized_name = normalize(counterparty_name)
        if not counterparty_id:
            continue
        fin_company = fin_by_id.get(counterparty_id)
        if fin_company is None:
            add_issue(
                'BANK_ORPHAN_COUNTERPARTY_ID',
                'critical',
                'Cuentas bancarias',
                counterparty_name or counterparty_id,
                'El movimiento bancario referencia una empresa inexistente en finanzas_catalog_companies.',
                f"movement={movement.get('id')},counterparty_id={counterparty_id}",
            )
            continue

        fin_name = str(fin_company.get('name') or '').strip()
        if normalized_name and normalize(fin_name) != normalized_name:
            add_issue(
                'BANK_NAME_MISMATCH',
                'high',
                'Cuentas bancarias',
                counterparty_name or fin_name,
                'counterparty_name_snapshot no coincide con el nombre de la empresa ligada en Finanzas.',
                f"movement={movement.get('id')},counterparty_id={counterparty_id},fin_name={fin_name}",
            )

        compras_rows = compras_by_name.get(normalized_name, [])
        ventas_rows = ventas_by_name.get(normalized_name, [])
        if compras_rows and ventas_rows:
            add_issue(
                'BANK_AMBIGUOUS_ALIAS',
                'medium',
                'Cuentas bancarias',
                counterparty_name or fin_name,
                'El movimiento usa un nombre que existe en Compras Mayoreo y Ventas Mayoreo; revisar que el counterparty_company_id canónico sea el correcto.',
                f"movement={movement.get('id')},counterparty_id={counterparty_id},source={fin_company.get('source')}",
            )

    summary = {
        'finanzas_companies': len(fin_companies),
        'compras_companies': len(compras_companies),
        'ventas_companies': len(ventas_companies),
        'supplier_invoices': len(invoices),
        'bank_movements': len(bank_movements),
        'issues': len(issues),
        'issues_by_type': {
            issue_type: sum(1 for row in issues if row['issue_type'] == issue_type)
            for issue_type in sorted({row['issue_type'] for row in issues})
        },
    }

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=['issue_type', 'severity', 'scope', 'company_name', 'details', 'refs'],
        )
        writer.writeheader()
        writer.writerows(issues)

    OUT_JSON.write_text(
        json.dumps(
            {
                'summary': summary,
                'issues': issues,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding='utf-8',
    )

    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print(f'CSV: {OUT_CSV}')
    print(f'JSON: {OUT_JSON}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
