begin;

alter type public.transformation_origin_type_v2
  add value if not exists 'SALE';

commit;
