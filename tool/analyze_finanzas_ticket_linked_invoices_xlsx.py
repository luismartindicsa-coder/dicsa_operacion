from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from zipfile import ZipFile
import csv
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

NS_MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
NS_REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
NS = {'a': NS_MAIN, 'r': NS_REL}
SUPABASE_URL = 'https://pjxncveymixxdntplchb.supabase.co'
SUPABASE_ANON_KEY = 'sb_publishable_0CPL9An-gAReMKpoDYhMtg_Da6Lc3qb'

MONTHS = {
    'ENERO': 1,
    'FEBRERO': 2,
    'MARZO': 3,
    'ABRIL': 4,
    'MAYO': 5,
    'JUNIO': 6,
    'JULIO': 7,
    'AGOSTO': 8,
    'SEPTIEMBRE': 9,
    'SETIEMBRE': 9,
    'OCTUBRE': 10,
    'NOVIEMBRE': 11,
    'DICIEMBRE': 12,
    'ENE': 1,
    'ENER': 1,
    'FEB': 2,
    'MAR': 3,
    'MZO': 3,
    'ABR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AGO': 8,
    'AGT': 8,
    'SEP': 9,
    'SEPT': 9,
    'OCT': 10,
    'NOV': 11,
    'DIC': 12,
}


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


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def as_money(value: Decimal) -> str:
    return str(value.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP))


def parse_amount(value) -> Decimal:
    raw = str(value or '').replace(',', '').replace('$', '').strip()
    if not raw:
        return Decimal('0.00')
    try:
        return Decimal(raw).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    except Exception:
        return Decimal('0.00')


def excel_date_to_iso(value) -> str:
    if value in (None, ''):
        return ''
    try:
        serial = float(value)
    except Exception:
        return str(value).strip()
    base = datetime(1899, 12, 30)
    return (base + timedelta(days=serial)).strftime('%Y-%m-%d')


def parse_xlsx_rows(path: Path):
    with ZipFile(path) as zf:
        shared = []
        if 'xl/sharedStrings.xml' in zf.namelist():
            root = ET.fromstring(zf.read('xl/sharedStrings.xml'))
            for si in root.findall(f'{{{NS_MAIN}}}si'):
                shared.append(''.join((t.text or '') for t in si.iterfind('.//a:t', NS)))

        workbook = ET.fromstring(zf.read('xl/workbook.xml'))
        rels = ET.fromstring(zf.read('xl/_rels/workbook.xml.rels'))
        relmap = {rel.attrib['Id']: rel.attrib['Target'] for rel in rels}
        first_sheet = workbook.find('a:sheets', NS)[0]
        rid = first_sheet.attrib[f'{{{NS_REL}}}id']
        target = 'xl/' + relmap[rid]
        root = ET.fromstring(zf.read(target))
        rows = []
        for row in root.find('a:sheetData', NS).findall('a:row', NS):
            values = []
            for cell in row.findall('a:c', NS):
                cell_type = cell.attrib.get('t')
                node = cell.find('a:v', NS)
                if node is None:
                    values.append('')
                    continue
                raw = node.text or ''
                if cell_type == 's' and raw.isdigit():
                    idx = int(raw)
                    values.append(shared[idx] if idx < len(shared) else raw)
                else:
                    values.append(raw)
            rows.append(values)
        return rows


def parse_company_ids_from_sql(path: Path, row_id_prefix: str, output_prefix: str) -> dict[str, str]:
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(r"\('([^']+)'\s*,\s*'([^']+)'\s*,")
    result: dict[str, str] = {}
    for row_id, name in pattern.findall(text):
        if not row_id.startswith(row_id_prefix):
            continue
        norm = normalize(name)
        if norm:
            result[norm] = f'{output_prefix}{row_id}'
    return result


def parse_finance_direct_ids(path: Path) -> dict[str, str]:
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(r"\('([^']+)'\s*,\s*'([^']+)'\s*,\s*'DIRECTO'\s*,")
    result: dict[str, str] = {}
    for row_id, name in pattern.findall(text):
        norm = normalize(name)
        if norm:
            result[norm] = row_id
    return result


def resolve_provider_id(
    norm_name: str,
    direct_map: dict[str, str],
    compras_map: dict[str, str],
    ventas_map: dict[str, str],
) -> tuple[str, str]:
    if norm_name in direct_map:
        return direct_map[norm_name], 'DIRECTO'
    if norm_name in compras_map:
        return compras_map[norm_name], 'COMPRAS'
    if norm_name in ventas_map:
        return ventas_map[norm_name], 'VENTAS'
    return '', ''


def suggested_target(provider_name: str) -> tuple[str, str]:
    raw = normalize(provider_name)
    target_company = 'VH' if ' VH ' in f' {raw} ' or raw.startswith('VH ') else 'DICSA'
    target_branch = 'MAZATLAN' if 'MAZATLAN' in raw else 'CELAYA'
    return target_company, target_branch


def provider_slug(provider_name: str) -> str:
    raw = normalize(provider_name).lower()
    return raw.replace(' ', '-') or 'provider'


def parse_date_cell(value) -> str:
    raw = excel_date_to_iso(value)
    raw = raw.strip()
    if not raw:
        return ''
    if re.fullmatch(r'\d{4}-\d{2}-\d{2}', raw):
        return raw
    for fmt in ('%d/%m/%Y', '%d/%m/%y', '%Y-%m-%d'):
        try:
            return datetime.strptime(raw, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    return raw


def parse_report_range(comment: str) -> tuple[str, str, str]:
    raw = (comment or '').strip().upper()
    if not raw:
        return '', '', 'SIN_COMENTARIO'
    text = raw
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
    normalized = re.sub(r'[^A-Z0-9\-/ ]+', ' ', text)
    normalized = re.sub(r'\s+', ' ', normalized).strip()
    tokens = normalized.split()
    year = None
    month = None
    for token in reversed(tokens):
        if year is None and re.fullmatch(r'20\d{2}', token):
            year = int(token)
            continue
        if year is not None and month is None and token in MONTHS:
            month = MONTHS[token]
            break
    if month is None:
        for alias, alias_month in sorted(MONTHS.items(), key=lambda item: -len(item[0])):
            if re.search(rf'(?<![A-Z]){re.escape(alias)}(?![A-Z])', normalized):
                month = alias_month
                break
    range_match = re.search(r'(\d{1,2})\s*[-/]\s*(\d{1,2})', normalized)
    if year is None or month is None or range_match is None:
        return '', '', 'RANGO_NO_RECONOCIDO'
    day_from = int(range_match.group(1))
    day_to = int(range_match.group(2))
    try:
        start = date(year, month, day_from)
        end = date(year, month, day_to)
    except ValueError:
        return '', '', 'RANGO_INVALIDO'
    if end < start:
        return '', '', 'RANGO_INVALIDO'
    return start.isoformat(), end.isoformat(), 'OK'


@dataclass(frozen=True)
class TicketRow:
    row_number: int
    ticket_id: str
    date_iso: str
    ticket_number: str
    provider: str
    provider_norm: str
    amount: Decimal
    factura_status: str
    import_status: str
    comentario: str


def load_ticket_rows(path: Path) -> list[TicketRow]:
    with path.open(encoding='utf-8', newline='') as handle:
        reader = csv.DictReader(handle)
        rows: list[TicketRow] = []
        for row in reader:
            row_number = int((row.get('row_number') or '0').strip() or '0')
            rows.append(
                TicketRow(
                    row_number=row_number,
                    ticket_id=f'ct_legacy_row_{row_number}',
                    date_iso=(row.get('date') or '').strip(),
                    ticket_number=(row.get('ticket') or '').strip(),
                    provider=(row.get('provider') or '').strip(),
                    provider_norm=normalize(row.get('provider') or ''),
                    amount=parse_amount(row.get('amount')),
                    factura_status=(row.get('target_factura_status') or '').strip(),
                    import_status=(row.get('import_status') or '').strip(),
                    comentario=(row.get('comentario') or '').strip(),
                )
            )
    return rows


def load_ticket_rows_from_snapshot(path: Path) -> list[TicketRow]:
    payload = json.loads(path.read_text(encoding='utf-8'))
    rows: list[TicketRow] = []
    for row in payload:
        provider = (row.get('provider_name_snapshot') or '').strip()
        raw_date = (row.get('ticket_date') or '').strip()
        rows.append(
            TicketRow(
                row_number=0,
                ticket_id=(row.get('id') or '').strip(),
                date_iso=_calendar_date_from_iso(raw_date) if raw_date else '',
                ticket_number=(row.get('ticket_number') or '').strip(),
                provider=provider,
                provider_norm=normalize(provider),
                amount=parse_amount(row.get('amount')),
                factura_status=(row.get('factura_status') or '').strip(),
                import_status='SNAPSHOT',
                comentario='',
            )
        )
    return rows


def _calendar_date_from_iso(raw: str) -> str:
    parsed = datetime.fromisoformat(raw.replace('Z', '+00:00'))
    return parsed.date().isoformat()


def load_ticket_rows_from_remote() -> list[TicketRow]:
    rows: list[TicketRow] = []
    offset = 0
    page_size = 1000
    while True:
        params = urlencode(
            {
                'select': 'id,ticket_date,ticket_number,provider_name_snapshot,amount,factura_status',
                'order': 'ticket_date.asc,ticket_number.asc',
                'limit': str(page_size),
                'offset': str(offset),
            }
        )
        url = f'{SUPABASE_URL}/rest/v1/compras_tickets?{params}'
        try:
            req = Request(
                url,
                headers={
                    'apikey': SUPABASE_ANON_KEY,
                    'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
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
                        f'Authorization: Bearer {SUPABASE_ANON_KEY}',
                    ],
                    text=True,
                )
            )
        if not payload:
            break
        for row in payload:
            provider = (row.get('provider_name_snapshot') or '').strip()
            raw_date = (row.get('ticket_date') or '').strip()
            rows.append(
                TicketRow(
                    row_number=0,
                    ticket_id=(row.get('id') or '').strip(),
                    date_iso=_calendar_date_from_iso(raw_date) if raw_date else '',
                    ticket_number=(row.get('ticket_number') or '').strip(),
                    provider=provider,
                    provider_norm=normalize(provider),
                    amount=parse_amount(row.get('amount')),
                    factura_status=(row.get('factura_status') or '').strip(),
                    import_status='REMOTE',
                    comentario='',
                )
            )
        if len(payload) < page_size:
            break
        offset += page_size
    return rows


def normalize_invoice_row(row, header_len):
    values = list(row)
    while len(values) < header_len:
        values.append('')
    values = values[:header_len]
    populated = [str(cell).strip() for cell in values if str(cell).strip()]
    estado_candidate = str(values[6]).strip().upper()
    comentario_candidate = str(values[7]).strip().upper()
    if (
        len(populated) == header_len - 1
        and estado_candidate in {'PENDIENTE', 'PAGADA', 'PAGADO', 'VENCIDA', 'VENCIDO'}
        and comentario_candidate
    ):
        fecha, tipo, referencia, proveedor, importe, fecha_pago, estado, comentario, _ = values
        return [
            fecha,
            tipo,
            referencia,
            proveedor,
            importe,
            fecha_pago,
            '',
            estado,
            comentario,
        ]
    return values


def build_sql(review_rows: list[dict]) -> str:
    lines = ['-- Generated from legacy ticket-linked supplier invoices']
    for row in review_rows:
        if row['match_status'] != 'EXACT':
            continue
        due_sql = 'null' if not row['fecha_vencimiento'] else sql_quote(f"{row['fecha_vencimiento']}T00:00:00")
        notes_sql = 'null' if not row['comentario'] else sql_quote(row['comentario'])
        invoice_date_sql = sql_quote(f"{row['fecha']}T00:00:00")
        today = datetime.now().date().strftime('%Y-%m-%d')
        provider_name_sql = sql_quote(row['proveedor'])
        amount_sql = row['importe']
        start_sql = sql_quote(row['date_from'])
        end_sql = sql_quote(row['date_to'])
        folio_sql = sql_quote(row['referencia'])
        invoice_id_sql = sql_quote(row['invoice_id'])
        provider_id_sql = sql_quote(row['provider_id'])
        target_company_sql = sql_quote(row['target_company'])
        target_branch_sql = sql_quote(row['target_branch'])
        notes_source = row['provider_source'] or 'DIRECTO'
        provider_note = (
            'SINCRONIZADO DESDE COMPRAS MAYOREO'
            if notes_source == 'COMPRAS'
            else 'SINCRONIZADO DESDE VENTAS MAYOREO'
            if notes_source == 'VENTAS'
            else 'IMPORTADO DESDE LEGACY FACTURAS PROVEEDOR'
        )
        lines.append(
            f"""with ensured_provider as (
  insert into public.finanzas_catalog_companies
    (id, name, source, linked_name, is_active, notes)
  values (
    {provider_id_sql},
    {provider_name_sql},
    {sql_quote(notes_source)},
    {provider_name_sql},
    true,
    {sql_quote(provider_note)}
  )
  on conflict (id) do update set
    name = excluded.name,
    source = excluded.source,
    linked_name = excluded.linked_name,
    is_active = true
  returning id
),
matched_tickets as (
  select
    t.id,
    t.amount
  from public.compras_tickets t
  where upper(trim(t.provider_name_snapshot)) = upper(trim({provider_name_sql}))
    and t.ticket_date::date between {start_sql}::date and {end_sql}::date
    and t.factura_status = 'PENDIENTE_DE_FACTURAR'
),
ticket_totals as (
  select
    count(*) as ticket_count,
    coalesce(sum(amount), 0)::numeric(14,2) as total_amount
  from matched_tickets
),
inserted_invoice as (
  insert into public.finanzas_supplier_invoices
    (id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)
  select
    {invoice_id_sql},
    {provider_id_sql},
    {provider_name_sql},
    {target_company_sql},
    {target_branch_sql},
    {folio_sql},
    'TICKETS',
    {invoice_date_sql},
    {due_sql},
    {amount_sql},
    {amount_sql},
    case
      when {due_sql} is not null and {due_sql}::timestamptz < '{today}'::date then 'VENCIDA'
      else 'PENDIENTE'
    end,
    {notes_sql},
    'NORMAL',
    null
  from ticket_totals
  where ticket_count > 0
    and abs(total_amount - {amount_sql}) <= 0.01
    and not exists (
      select 1
      from public.finanzas_supplier_invoices existing
      where existing.provider_id = {provider_id_sql}
        and upper(trim(existing.invoice_folio)) = upper(trim({folio_sql}))
    )
  returning id
),
inserted_links as (
  insert into public.finanzas_supplier_invoice_tickets
    (id, invoice_id, ticket_id, applied_amount)
  select
    'fin-inv-ticket-' || {invoice_id_sql} || '-' || mt.id,
    {invoice_id_sql},
    mt.id,
    mt.amount
  from matched_tickets mt
  where exists (select 1 from inserted_invoice)
  on conflict (ticket_id) do nothing
  returning ticket_id
)
update public.compras_tickets
set factura_status = 'FACTURADO'
where id in (select ticket_id from inserted_links);"""
        )
    return '\n\n'.join(lines) + '\n'


def main(xlsx_path: str):
    base = Path('apps/dicsa_operacion')
    rows = parse_xlsx_rows(Path(xlsx_path))
    header = rows[0]
    data = rows[1:]

    direct_map = parse_finance_direct_ids(
        base / 'supabase/migrations/20260610180500_import_finanzas_provider_catalog_from_legacy_csv.sql'
    )
    compras_map = parse_company_ids_from_sql(
        base / 'supabase/migrations/20260610190000_import_compras_catalog_from_legacy_csv.sql',
        'cp_import_',
        'compras_',
    )
    ventas_map = parse_company_ids_from_sql(
        base / 'supabase/migrations/20260610173000_import_mayoreo_catalog_from_legacy_csv.sql',
        'co_import_',
        'ventas_',
    )
    snapshot_path = base / 'docs/migrations/current_compras_tickets_snapshot.json'
    monroe_snapshot_path = base / 'docs/migrations/current_monroe_tickets_snapshot.json'
    if snapshot_path.exists() and snapshot_path.stat().st_size > 0:
        ticket_rows = load_ticket_rows_from_snapshot(snapshot_path)
        ticket_source = 'CURRENT_TICKETS_SNAPSHOT'
    elif monroe_snapshot_path.exists() and monroe_snapshot_path.stat().st_size > 0:
        ticket_rows = load_ticket_rows_from_snapshot(monroe_snapshot_path)
        ticket_source = 'CURRENT_MONROE_TICKETS_SNAPSHOT'
    else:
        try:
            ticket_rows = load_ticket_rows_from_remote()
            ticket_source = 'REMOTE_DB'
        except Exception:
            ticket_rows = load_ticket_rows(
                base / 'docs/migrations/compras_legacy_tickets_review.csv'
            )
            ticket_source = 'LEGACY_REVIEW_CSV'
    tickets_by_provider: dict[str, list[TicketRow]] = defaultdict(list)
    for ticket in ticket_rows:
        if ticket.import_status not in {
            'IMPORTABLE',
            'REVIEW',
            'REMOTE',
            'SNAPSHOT',
        }:
            continue
        tickets_by_provider[ticket.provider_norm].append(ticket)

    review_rows: list[dict] = []
    stats = {
        'rows': 0,
        'exact': 0,
        'mismatch': 0,
        'no_provider': 0,
        'no_range': 0,
        'no_tickets': 0,
    }

    for idx, raw in enumerate(data, start=2):
        values = normalize_invoice_row(raw, len(header))
        row = dict(zip(header, values))
        fecha = parse_date_cell(row.get('Fecha'))
        tipo = str(row.get('Tipo') or '').strip()
        referencia = str(row.get('Referencia') or '').strip()
        proveedor = str(row.get('Proveedor') or '').strip()
        importe = parse_amount(row.get('Importe'))
        fecha_pago = parse_date_cell(row.get('Fecha Pago'))
        fecha_venc = parse_date_cell(row.get('Fecha Venci'))
        estado = str(row.get('Estado') or '').strip()
        comentario = str(row.get('Comentario') or '').strip()
        provider_norm = normalize(proveedor)
        provider_id, provider_source = resolve_provider_id(
            provider_norm,
            direct_map=direct_map,
            compras_map=compras_map,
            ventas_map=ventas_map,
        )
        date_from, date_to, range_status = parse_report_range(comentario)
        candidate_rows: list[TicketRow] = []
        if provider_norm and date_from and date_to:
            for ticket in tickets_by_provider.get(provider_norm, []):
                if ticket.factura_status != 'PENDIENTE_DE_FACTURAR':
                    continue
                if date_from <= ticket.date_iso <= date_to:
                    candidate_rows.append(ticket)
        candidate_total = sum((ticket.amount for ticket in candidate_rows), Decimal('0.00'))
        difference = (candidate_total - importe).quantize(
            Decimal('0.01'),
            rounding=ROUND_HALF_UP,
        )

        if not provider_id:
            match_status = 'NO_PROVIDER'
        elif range_status != 'OK':
            match_status = range_status
        elif not candidate_rows:
            match_status = 'NO_TICKETS'
        elif abs(difference) <= Decimal('0.01'):
            match_status = 'EXACT'
        else:
            match_status = 'MISMATCH'

        invoice_id = f'fin-invoice-legacy-ticketed-{provider_slug(proveedor)}-{idx}'
        target_company, target_branch = suggested_target(proveedor)
        review_rows.append(
            {
                'row_number': idx,
                'fecha': fecha,
                'tipo': tipo,
                'referencia': referencia,
                'proveedor': proveedor,
                'provider_id': provider_id,
                'provider_source': provider_source,
                'importe': as_money(importe),
                'fecha_pago': fecha_pago,
                'fecha_vencimiento': fecha_venc,
                'estado': estado,
                'comentario': comentario,
                'date_from': date_from,
                'date_to': date_to,
                'candidate_ticket_count': len(candidate_rows),
                'candidate_ticket_total': as_money(candidate_total),
                'difference': as_money(difference),
                'candidate_ticket_ids': '|'.join(ticket.ticket_id for ticket in candidate_rows),
                'candidate_ticket_numbers': '|'.join(ticket.ticket_number for ticket in candidate_rows),
                'match_status': match_status,
                'target_company': target_company,
                'target_branch': target_branch,
                'invoice_id': invoice_id,
            }
        )
        stats['rows'] += 1
        if match_status == 'EXACT':
            stats['exact'] += 1
        elif match_status == 'MISMATCH':
            stats['mismatch'] += 1
        elif match_status == 'NO_PROVIDER':
            stats['no_provider'] += 1
        elif match_status in {'SIN_COMENTARIO', 'RANGO_NO_RECONOCIDO', 'RANGO_INVALIDO'}:
            stats['no_range'] += 1
        elif match_status == 'NO_TICKETS':
            stats['no_tickets'] += 1

    review_path = base / 'docs/migrations/finanzas_ticket_linked_invoices_review.csv'
    with review_path.open('w', encoding='utf-8', newline='') as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                'row_number',
                'fecha',
                'tipo',
                'referencia',
                'proveedor',
                'provider_id',
                'provider_source',
                'importe',
                'fecha_pago',
                'fecha_vencimiento',
                'estado',
                'comentario',
                'date_from',
                'date_to',
                'candidate_ticket_count',
                'candidate_ticket_total',
                'difference',
                'candidate_ticket_ids',
                'candidate_ticket_numbers',
                'match_status',
                'target_company',
                'target_branch',
                'invoice_id',
            ],
        )
        writer.writeheader()
        writer.writerows(review_rows)

    sql_path = base / 'docs/migrations/finanzas_ticket_linked_invoices_import.sql'
    sql_path.write_text(build_sql(review_rows), encoding='utf-8')

    print('Review CSV:', review_path)
    print('SQL:', sql_path)
    print('Ticket source:', ticket_source)
    for key, value in stats.items():
        print(f'{key}: {value}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Uso: python3 apps/dicsa_operacion/tool/analyze_finanzas_ticket_linked_invoices_xlsx.py /ruta/al/archivo.xlsx')
        raise SystemExit(1)
    main(sys.argv[1])
