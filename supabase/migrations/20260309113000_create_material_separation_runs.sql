begin;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'material_separation_source_mode'
  ) THEN
    CREATE TYPE public.material_separation_source_mode AS ENUM (
      'MIXED',
      'DIRECT'
    );
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.material_separation_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  op_date date NOT NULL,
  shift text NOT NULL,
  source_material text NOT NULL,
  source_mode public.material_separation_source_mode NOT NULL,
  commercial_material_code text NOT NULL,
  weight_kg numeric(14,3) NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT material_separation_runs_shift_chk CHECK (
    shift IN ('DAY', 'NIGHT')
  ),
  CONSTRAINT material_separation_runs_source_material_chk CHECK (
    source_material IN ('SCRAP', 'PAPER')
  ),
  CONSTRAINT material_separation_runs_commercial_code_trim_chk CHECK (
    commercial_material_code = btrim(commercial_material_code)
    AND length(commercial_material_code) > 0
  ),
  CONSTRAINT material_separation_runs_weight_positive_chk CHECK (
    weight_kg > 0
  )
);

ALTER TABLE public.material_separation_runs
  ADD COLUMN IF NOT EXISTS op_date date,
  ADD COLUMN IF NOT EXISTS shift text,
  ADD COLUMN IF NOT EXISTS source_material text,
  ADD COLUMN IF NOT EXISTS source_mode public.material_separation_source_mode,
  ADD COLUMN IF NOT EXISTS commercial_material_code text,
  ADD COLUMN IF NOT EXISTS weight_kg numeric(14,3),
  ADD COLUMN IF NOT EXISTS notes text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS material_separation_runs_material_date_idx
  ON public.material_separation_runs (source_material, op_date DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS material_separation_runs_commercial_idx
  ON public.material_separation_runs (commercial_material_code, op_date DESC);

CREATE OR REPLACE FUNCTION public.set_material_separation_runs_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_material_separation_runs_updated_at
  ON public.material_separation_runs;

CREATE TRIGGER trg_material_separation_runs_updated_at
BEFORE UPDATE ON public.material_separation_runs
FOR EACH ROW
EXECUTE FUNCTION public.set_material_separation_runs_updated_at();

commit;
