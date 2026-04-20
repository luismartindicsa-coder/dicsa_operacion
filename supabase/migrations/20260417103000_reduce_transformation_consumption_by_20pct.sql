begin;

update public.material_transformation_runs_v2
   set input_weight_kg = round((input_weight_kg * 0.8)::numeric, 3),
       updated_at = now()
 where input_weight_kg > 0;

commit;
