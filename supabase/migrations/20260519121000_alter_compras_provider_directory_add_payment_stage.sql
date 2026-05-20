alter table public.compras_provider_directory
add column if not exists payment_stage text not null default 'AL_CORRIENTE';

update public.compras_provider_directory
set payment_stage = 'AL_CORRIENTE'
where payment_stage is null or btrim(payment_stage) = '';

create index if not exists compras_provider_directory_payment_stage_idx
on public.compras_provider_directory (payment_stage);
