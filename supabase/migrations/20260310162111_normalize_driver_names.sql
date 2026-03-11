begin;

update public.employees as e
set full_name = normalized.normalized_full_name
from (
  select
    id,
    trim(
      regexp_replace(
        upper(
          translate(
            full_name,
            'áàäâãÁÀÄÂÃéèëêÉÈËÊíìïîÍÌÏÎóòöôõÓÒÖÔÕúùüûÚÙÜÛçÇ',
            'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcC'
          )
        ),
        '\s+',
        ' ',
        'g'
      )
    ) as normalized_full_name
  from public.employees
  where is_driver = true
) as normalized
where e.id = normalized.id
  and e.full_name is distinct from normalized.normalized_full_name;

commit;
