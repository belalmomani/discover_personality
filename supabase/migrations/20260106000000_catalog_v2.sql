-- Adds the 10 new tests to the shareable catalog (weights = number of questions). Run AFTER 20260105000000_similarity_cache.sql. Safe to re-run.
insert into public.assessment_catalog (test_id, dims, items) values
  ('x_riasec', 6, 18),
  ('x_grit', 2, 6),
  ('x_lifesat', 1, 6),
  ('x_selfesteem', 1, 6),
  ('x_optimism', 1, 6),
  ('x_emoreg', 2, 6),
  ('x_empathy', 3, 9),
  ('x_hsp', 1, 6),
  ('x_procrast', 1, 6),
  ('x_growth', 1, 6)
on conflict (test_id) do update set dims = excluded.dims, items = excluded.items;
