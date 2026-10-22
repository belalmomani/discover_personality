import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks of the cache migration (the SQL itself must still be run in Supabase).
void main() {
  final sql = File('supabase/migrations/20260105000000_similarity_cache.sql').readAsStringSync();

  test('cache table is internal: RLS on, no client grants, ordered pairs, cascade on account deletion', () {
    expect(sql, contains('alter table public.similarity_cache enable row level security'));
    expect(sql, contains('revoke all on public.similarity_cache from authenticated, anon'));
    expect(sql, contains('check (user_a < user_b)'));
    expect(sql, contains('references auth.users(id) on delete cascade'));
    expect(sql.contains('create policy'), isFalse);
  });

  test('refresh and purge functions are internal-only and SECURITY DEFINER with a fixed search_path', () {
    expect(sql, contains('revoke all on function public.refresh_similarity_for(uuid) from public, anon, authenticated'));
    expect(sql, contains('revoke all on function public.purge_similarity() from public, anon, authenticated'));
    final fns = RegExp(r'create or replace function public\.(\w+)\(([\s\S]*?)\n\$\$;').allMatches(sql).toList();
    expect(fns.length, 4);
    for (final m in fns) {
      expect(m.group(0)!.contains('security definer'), isTrue, reason: m.group(1));
      expect(m.group(0)!.contains('set search_path = public'), isTrue, reason: m.group(1));
    }
  });

  test('find_similar reads the cache and no longer computes similarity per candidate', () {
    final find = RegExp(r'create or replace function public\.find_similar[\s\S]*?\n\$\$;').firstMatch(sql)!.group(0)!;
    expect(find, contains('public.similarity_cache'));
    expect(find.contains('pair_similarity'), isFalse);
    expect(find, contains('greatest(coalesce(min_similarity'));
    for (final cond in ['p.share_results', 'p.age_confirmed', 'not p.banned', 'p.visible', 'public.is_blocked(auth.uid(), p.id)']) {
      expect(find, contains(cond), reason: cond);
    }
  });

  test('the cache is refreshed only when published scores really change, and keeps the same validation', () {
    final pub = RegExp(r'create or replace function public\.publish_scores_batch[\s\S]*?\n\$\$;').firstMatch(sql)!.group(0)!;
    expect(pub, contains('prev is distinct from arr'));
    expect(pub, contains('if changed then perform public.refresh_similarity_for(auth.uid())'));
    for (final check in ["raise exception 'unknown_test'", "raise exception 'invalid_scores'", 'array_length(arr, 1) <> cat.dims', 'v < 0 or v > 1', "raise exception 'not_eligible'"]) {
      expect(pub, contains(check), reason: check);
    }
  });

  test('stopping sharing purges cached pairs and existing users are backfilled once', () {
    expect(sql, contains('create trigger trg_purge_similarity after delete on public.shared_scores'));
    expect(sql, contains('perform public.refresh_similarity_for(u)'));
    expect(sql, contains('s.similarity >= 40'));
  });

  test('no real-money or payment logic is present', () {
    expect(sql.toLowerCase().contains('paypal'), isFalse);
    expect(sql.toLowerCase().contains('payout'), isFalse);
  });
}
