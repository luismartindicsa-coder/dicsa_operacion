begin;

-- Enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_item_category') THEN
    CREATE TYPE public.inventory_item_category AS ENUM (
      'herramienta',
      'uniforme',
      'material',
      'consumible',
      'refaccion'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_movement_type') THEN
    CREATE TYPE public.inventory_movement_type AS ENUM (
      'apertura',
      'entrada',
      'salida',
      'ajuste',
      'cierre'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'inventory_monthly_cut_status') THEN
    CREATE TYPE public.inventory_monthly_cut_status AS ENUM (
      'abierto',
      'en_revision',
      'cerrado'
    );
  END IF;
END
$$;

-- Catalog
CREATE TABLE IF NOT EXISTS public.inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  category public.inventory_item_category NOT NULL,
  description text,
  unit text NOT NULL,
  current_stock numeric(14,3) NOT NULL DEFAULT 0,
  minimum_stock numeric(14,3) NOT NULL DEFAULT 0,
  location text NOT NULL,
  assigned_to text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT inventory_items_code_trim_chk CHECK (code = btrim(code) AND length(code) > 0),
  CONSTRAINT inventory_items_name_trim_chk CHECK (name = btrim(name) AND length(name) > 0),
  CONSTRAINT inventory_items_unit_trim_chk CHECK (unit = btrim(unit) AND length(unit) > 0),
  CONSTRAINT inventory_items_location_trim_chk CHECK (location = btrim(location) AND length(location) > 0),
  CONSTRAINT inventory_items_stock_nonnegative_chk CHECK (current_stock >= 0 AND minimum_stock >= 0)
);

ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS code text,
  ADD COLUMN IF NOT EXISTS name text,
  ADD COLUMN IF NOT EXISTS category public.inventory_item_category,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS unit text,
  ADD COLUMN IF NOT EXISTS current_stock numeric(14,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS minimum_stock numeric(14,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS assigned_to text,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS inventory_items_category_idx ON public.inventory_items (category);
CREATE INDEX IF NOT EXISTS inventory_items_location_idx ON public.inventory_items (location);
CREATE INDEX IF NOT EXISTS inventory_items_active_idx ON public.inventory_items (is_active);

-- Movements
CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
  movement_type public.inventory_movement_type NOT NULL,
  quantity numeric(14,3) NOT NULL,
  area text,
  responsible_name text NOT NULL,
  reason text NOT NULL,
  reference text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT inventory_movements_qty_chk CHECK (
    (movement_type = 'ajuste' AND quantity <> 0) OR
    (movement_type <> 'ajuste' AND quantity > 0)
  ),
  CONSTRAINT inventory_movements_responsible_trim_chk CHECK (
    responsible_name = btrim(responsible_name) AND length(responsible_name) > 0
  ),
  CONSTRAINT inventory_movements_reason_trim_chk CHECK (
    reason = btrim(reason) AND length(reason) > 0
  )
);

ALTER TABLE public.inventory_movements
  ADD COLUMN IF NOT EXISTS item_id uuid,
  ADD COLUMN IF NOT EXISTS movement_type public.inventory_movement_type,
  ADD COLUMN IF NOT EXISTS quantity numeric(14,3),
  ADD COLUMN IF NOT EXISTS area text,
  ADD COLUMN IF NOT EXISTS responsible_name text,
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS reference text,
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS inventory_movements_item_idx ON public.inventory_movements (item_id, created_at DESC);
CREATE INDEX IF NOT EXISTS inventory_movements_type_idx ON public.inventory_movements (movement_type, created_at DESC);
CREATE INDEX IF NOT EXISTS inventory_movements_area_idx ON public.inventory_movements (area);

-- Monthly cuts
CREATE TABLE IF NOT EXISTS public.inventory_monthly_cuts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month int NOT NULL,
  year int NOT NULL,
  status public.inventory_monthly_cut_status NOT NULL DEFAULT 'abierto',
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  opened_by uuid,
  closed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT inventory_monthly_cuts_month_chk CHECK (month BETWEEN 1 AND 12),
  CONSTRAINT inventory_monthly_cuts_year_chk CHECK (year BETWEEN 2020 AND 2100),
  CONSTRAINT inventory_monthly_cuts_period_unique UNIQUE (month, year)
);

ALTER TABLE public.inventory_monthly_cuts
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS month int,
  ADD COLUMN IF NOT EXISTS year int,
  ADD COLUMN IF NOT EXISTS status public.inventory_monthly_cut_status NOT NULL DEFAULT 'abierto',
  ADD COLUMN IF NOT EXISTS opened_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS closed_at timestamptz,
  ADD COLUMN IF NOT EXISTS opened_by uuid,
  ADD COLUMN IF NOT EXISTS closed_by uuid,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.inventory_monthly_cuts
SET id = gen_random_uuid()
WHERE id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS inventory_monthly_cuts_id_uidx
  ON public.inventory_monthly_cuts (id);

CREATE INDEX IF NOT EXISTS inventory_monthly_cuts_status_idx ON public.inventory_monthly_cuts (status, year DESC, month DESC);

CREATE TABLE IF NOT EXISTS public.inventory_monthly_cut_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cut_id uuid NOT NULL REFERENCES public.inventory_monthly_cuts(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.inventory_items(id) ON DELETE RESTRICT,
  system_stock numeric(14,3) NOT NULL,
  physical_stock numeric(14,3) NOT NULL,
  difference numeric(14,3) NOT NULL DEFAULT 0,
  adjustment_applied boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT inventory_monthly_cut_lines_stock_chk CHECK (system_stock >= 0 AND physical_stock >= 0),
  CONSTRAINT inventory_monthly_cut_lines_unique UNIQUE (cut_id, item_id)
);

ALTER TABLE public.inventory_monthly_cut_lines
  ADD COLUMN IF NOT EXISTS cut_id uuid,
  ADD COLUMN IF NOT EXISTS item_id uuid,
  ADD COLUMN IF NOT EXISTS system_stock numeric(14,3),
  ADD COLUMN IF NOT EXISTS physical_stock numeric(14,3),
  ADD COLUMN IF NOT EXISTS difference numeric(14,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS adjustment_applied boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS inventory_monthly_cut_lines_cut_idx ON public.inventory_monthly_cut_lines (cut_id);
CREATE INDEX IF NOT EXISTS inventory_monthly_cut_lines_item_idx ON public.inventory_monthly_cut_lines (item_id);

-- Utility trigger: updated_at
CREATE OR REPLACE FUNCTION public.set_inventory_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_items_updated_at ON public.inventory_items;
CREATE TRIGGER trg_inventory_items_updated_at
BEFORE UPDATE ON public.inventory_items
FOR EACH ROW
EXECUTE FUNCTION public.set_inventory_updated_at();

DROP TRIGGER IF EXISTS trg_inventory_monthly_cuts_updated_at ON public.inventory_monthly_cuts;
CREATE TRIGGER trg_inventory_monthly_cuts_updated_at
BEFORE UPDATE ON public.inventory_monthly_cuts
FOR EACH ROW
EXECUTE FUNCTION public.set_inventory_updated_at();

DROP TRIGGER IF EXISTS trg_inventory_monthly_cut_lines_updated_at ON public.inventory_monthly_cut_lines;
CREATE TRIGGER trg_inventory_monthly_cut_lines_updated_at
BEFORE UPDATE ON public.inventory_monthly_cut_lines
FOR EACH ROW
EXECUTE FUNCTION public.set_inventory_updated_at();

-- Keep line difference always aligned
CREATE OR REPLACE FUNCTION public.compute_inventory_cut_line_difference()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.difference := NEW.physical_stock - NEW.system_stock;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_cut_line_difference ON public.inventory_monthly_cut_lines;
CREATE TRIGGER trg_inventory_cut_line_difference
BEFORE INSERT OR UPDATE OF system_stock, physical_stock ON public.inventory_monthly_cut_lines
FOR EACH ROW
EXECUTE FUNCTION public.compute_inventory_cut_line_difference();

-- Stock engine: update item stock whenever a movement is inserted
CREATE OR REPLACE FUNCTION public.apply_inventory_movement_to_stock()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_delta numeric(14,3);
BEGIN
  IF NEW.movement_type IN ('entrada', 'apertura') THEN
    v_delta := NEW.quantity;
  ELSIF NEW.movement_type IN ('salida', 'cierre') THEN
    v_delta := -NEW.quantity;
  ELSE
    -- ajuste accepts signed quantity
    v_delta := NEW.quantity;
  END IF;

  UPDATE public.inventory_items
  SET current_stock = current_stock + v_delta,
      updated_at = now()
  WHERE id = NEW.item_id
    AND (current_stock + v_delta) >= 0;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Movimiento invalido: el stock quedaria negativo para item_id=%', NEW.item_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_inventory_movement_to_stock ON public.inventory_movements;
CREATE TRIGGER trg_apply_inventory_movement_to_stock
AFTER INSERT ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.apply_inventory_movement_to_stock();

-- RLS
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_monthly_cuts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_monthly_cut_lines ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventory_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventory_movements TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventory_monthly_cuts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventory_monthly_cut_lines TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'inventory_items' AND policyname = 'inventory_items_authenticated_all'
  ) THEN
    CREATE POLICY inventory_items_authenticated_all
      ON public.inventory_items
      FOR ALL
      TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'inventory_movements' AND policyname = 'inventory_movements_authenticated_all'
  ) THEN
    CREATE POLICY inventory_movements_authenticated_all
      ON public.inventory_movements
      FOR ALL
      TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'inventory_monthly_cuts' AND policyname = 'inventory_monthly_cuts_authenticated_all'
  ) THEN
    CREATE POLICY inventory_monthly_cuts_authenticated_all
      ON public.inventory_monthly_cuts
      FOR ALL
      TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'inventory_monthly_cut_lines' AND policyname = 'inventory_monthly_cut_lines_authenticated_all'
  ) THEN
    CREATE POLICY inventory_monthly_cut_lines_authenticated_all
      ON public.inventory_monthly_cut_lines
      FOR ALL
      TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

COMMIT;
