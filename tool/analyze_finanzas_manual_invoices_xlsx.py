from zipfile import ZipFile
import xml.etree.ElementTree as ET
from pathlib import Path
import sys
import csv
import re
from datetime import datetime, timedelta

NS_MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
NS_REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
NS = {'a': NS_MAIN, 'r': NS_REL}


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
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def excel_date_to_iso(value) -> str:
    if value in (None, ''):
        return ''
    try:
        serial = float(value)
    except Exception:
        return str(value).strip()
    base = datetime(1899, 12, 30)
    return (base + timedelta(days=serial)).strftime('%Y-%m-%d')


def parse_amount(value) -> float:
    if value in (None, ''):
        return 0.0
    raw = str(value).replace(',', '').strip()
    try:
        return float(raw)
    except Exception:
        return 0.0


def is_numberish(value) -> bool:
    text = str(value or '').strip()
    if not text:
        return False
    return bool(re.fullmatch(r'-?\d+(?:\.\d+)?', text))


def normalize_legacy_manual_invoice_row(row, header_len):
    values = list(row)
    while len(values) < header_len:
        values.append('')
    values = values[:header_len]

    # Some legacy rows are shifted one column to the left:
    # Fecha | Tipo | Proveedor | Referencia | Importe | Estado | Comentario
    # instead of:
    # Fecha | Tipo | Referencia | Proveedor | Importe | Fecha Vencimiento | Estado | Comentario
    #
    # Heuristic:
    # - only 7 populated values or missing last cell
    # - current "proveedor" cell is numeric-ish
    # - current "referencia" cell is text-ish
    # - current "fecha_venc" cell contains a status like Pendiente
    populated = [str(cell).strip() for cell in values if str(cell).strip()]
    estado_candidate = str(values[5]).strip().upper()
    if (
        len(populated) == header_len - 1
        and is_numberish(values[3])
        and not is_numberish(values[2])
        and estado_candidate in {'PENDIENTE', 'PAGADA', 'PAGADO', 'VENCIDA', 'VENCIDO'}
    ):
        fecha, tipo, proveedor_real, referencia_real, importe, estado, comentario, _ = values
        return [
            fecha,
            tipo,
            referencia_real,
            proveedor_real,
            importe,
            '',
            estado,
            comentario,
        ]
    return values


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


def parse_company_ids_from_sql(path: Path, row_id_prefix: str, output_prefix: str) -> dict:
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(r"\('([^']+)'\s*,\s*'([^']+)'\s*,")
    result = {}
    for row_id, name in pattern.findall(text):
        if not row_id.startswith(row_id_prefix):
            continue
        norm = normalize(name)
        if not norm:
            continue
        result[norm] = f'{output_prefix}{row_id}'
    return result


def parse_finance_direct_ids(path: Path) -> dict:
    text = path.read_text(encoding='utf-8')
    pattern = re.compile(r"\('([^']+)'\s*,\s*'([^']+)'\s*,\s*'DIRECTO'\s*,")
    result = {}
    for row_id, name in pattern.findall(text):
        norm = normalize(name)
        if not norm:
            continue
        result[norm] = row_id
    return result


def resolve_provider_id(norm_name: str, direct_map: dict, compras_map: dict, ventas_map: dict):
    if norm_name in direct_map:
        return direct_map[norm_name], 'DIRECTO'
    if norm_name in compras_map:
        return compras_map[norm_name], 'COMPRAS'
    if norm_name in ventas_map:
        return ventas_map[norm_name], 'VENTAS'
    return '', ''


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def suggested_target(provider_name: str):
    raw = normalize(provider_name)
    target_company = 'VH' if ' VH ' in f' {raw} ' or raw.startswith('VH ') else 'DICSA'
    target_branch = 'MAZATLAN' if 'MAZATLAN' in raw else 'CELAYA'
    return target_company, target_branch


def build_sql(review_rows):
    lines = ['-- Generated from Facturas Manuales Pendientes.xlsx']
    provider_rows = []
    seen_provider_ids = set()
    for row in review_rows:
        if row['status'] != 'IMPORTAR' or not row['provider_id']:
            continue
        if row['provider_id'] in seen_provider_ids:
            continue
        seen_provider_ids.add(row['provider_id'])
        source = row['provider_source'] or 'DIRECTO'
        if source == 'COMPRAS':
            notes = 'SINCRONIZADO DESDE COMPRAS MAYOREO'
        elif source == 'VENTAS':
            notes = 'SINCRONIZADO DESDE VENTAS MAYOREO'
        else:
            notes = 'IMPORTADO DESDE LEGACY PROVEEDORES PAGOS 2026-06-10'
        provider_rows.append(
            "insert into public.finanzas_catalog_companies "
            "(id, name, source, linked_name, is_active, notes)\n"
            f"select {sql_quote(row['provider_id'])}, {sql_quote(row['proveedor'])}, {sql_quote(source)}, "
            f"{sql_quote(row['proveedor'])}, true, {sql_quote(notes)}\n"
            "where not exists (\n"
            "  select 1\n"
            "  from public.finanzas_catalog_companies existing\n"
            f"  where existing.id = {sql_quote(row['provider_id'])}\n"
            ");"
        )
    if provider_rows:
        lines.extend(provider_rows)
    for row in review_rows:
        if row['status'] != 'IMPORTAR':
            continue
        due_sql = 'null' if not row['fecha_vencimiento'] else sql_quote(f"{row['fecha_vencimiento']}T00:00:00")
        notes_sql = 'null' if not row['comentario'] else sql_quote(row['comentario'])
        invoice_date_sql = sql_quote(f"{row['fecha']}T00:00:00")
        today = datetime.now().date().strftime('%Y-%m-%d')
        status_sql = (
            "case "
            f"when {row['importe']} <= 0 then 'PAGADA' "
            f"when {due_sql} is not null and {row['fecha_vencimiento'] and sql_quote(row['fecha_vencimiento'] + 'T00:00:00') or 'null'}::timestamptz < '{today}'::date then 'VENCIDA' "
            "else 'PENDIENTE' end"
        )
        lines.append(
            "insert into public.finanzas_supplier_invoices "
            "(id, provider_id, provider_name_snapshot, target_company, target_branch, invoice_folio, origin_type, invoice_date, due_date, total_amount, balance_amount, status, notes, manual_priority, priority_note)\n"
            f"select {sql_quote(row['invoice_id'])}, {sql_quote(row['provider_id'])}, {sql_quote(row['proveedor'])}, "
            f"{sql_quote(row['target_company'])}, {sql_quote(row['target_branch'])}, {sql_quote(row['referencia'])}, 'MANUAL', "
            f"{invoice_date_sql}, {due_sql}, {row['importe']}, {row['importe']}, {status_sql}, {notes_sql}, 'NORMAL', null\n"
            "where not exists (\n"
            "  select 1\n"
            "  from public.finanzas_supplier_invoices existing\n"
            f"  where existing.provider_id = {sql_quote(row['provider_id'])}\n"
            f"    and upper(existing.invoice_folio) = upper({sql_quote(row['referencia'])})\n"
            ");"
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

    review_rows = []
    stats = {
        'rows': 0,
        'importable': 0,
        'missing_provider': 0,
        'non_factura_rows': 0,
    }

    for index, row in enumerate(data, start=2):
        if not any(str(cell).strip() for cell in row):
            continue
        row = normalize_legacy_manual_invoice_row(row, len(header))
        fecha, tipo, referencia, proveedor, importe, fecha_venc, estado, comentario = row[:8]
        stats['rows'] += 1
        provider_norm = normalize(proveedor)
        provider_id, provider_source = resolve_provider_id(
            provider_norm,
            direct_map,
            compras_map,
            ventas_map,
        )
        review = []
        if str(tipo).strip().upper() != 'FACTURA':
            review.append('tipo_distinto_factura')
            stats['non_factura_rows'] += 1
        if not provider_id:
            review.append('proveedor_no_en_catalogo_finanzas')
            stats['missing_provider'] += 1
        target_company, target_branch = suggested_target(proveedor)
        invoice_date = excel_date_to_iso(fecha)
        due_date = excel_date_to_iso(fecha_venc)
        amount = parse_amount(importe)
        invoice_id = (
            'fin-invoice-legacy-manual-'
            + re.sub(r'[^a-z0-9]+', '-', f"{provider_norm}-{referencia}-{invoice_date}".lower()).strip('-')
        )
        status = 'IMPORTAR' if not review else 'REVIEW'
        if status == 'IMPORTAR':
            stats['importable'] += 1
        review_rows.append({
            'row_number': index,
            'fecha': invoice_date,
            'tipo': str(tipo).strip(),
            'referencia': str(referencia).strip(),
            'proveedor': str(proveedor).strip(),
            'provider_id': provider_id,
            'provider_source': provider_source,
            'importe': f'{amount:.2f}',
            'fecha_vencimiento': due_date,
            'estado_legacy': str(estado).strip(),
            'comentario': str(comentario).strip(),
            'target_company': target_company,
            'target_branch': target_branch,
            'invoice_id': invoice_id,
            'status': status,
            'review_notes': '|'.join(review),
        })

    review_path = base / 'docs/migrations/finanzas_manual_invoices_review.csv'
    review_path.parent.mkdir(parents=True, exist_ok=True)
    with review_path.open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(review_rows[0].keys()) if review_rows else [])
        writer.writeheader()
        writer.writerows(review_rows)

    sql_path = base / 'docs/migrations/finanzas_manual_invoices_import.sql'
    sql_path.write_text(build_sql(review_rows), encoding='utf-8')

    print(stats)
    print(f'REVIEW={review_path}')
    print(f'SQL={sql_path}')


if __name__ == '__main__':
    main(sys.argv[1])
