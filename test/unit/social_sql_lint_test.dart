import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the migration text (the SQL itself must still be run in Supabase).
void main() {
  final sql = File('supabase/migrations/20260102000000_social.sql').readAsStringSync();

  test('every new table has RLS enabled', () {
    final tables = RegExp(r'create table if not exists public\.(\w+)').allMatches(sql).map((m) => m.group(1)!).toList();
    expect(tables, containsAll(['admin_users', 'app_settings', 'shared_features', 'blocks', 'abuse_reports', 'conversations', 'messages', 'wallets', 'coin_ledger', 'gifts', 'gift_sends']));
    for (final t in tables) {
      expect(sql.contains('alter table public.$t enable row level security'), isTrue, reason: 'RLS missing on $t');
    }
  });

  test('clients cannot write directly to money, chat, block or profile tables', () {
    expect(sql, contains('revoke insert, update, delete on public.wallets from authenticated, anon'));
    expect(sql, contains('revoke insert, update, delete on public.coin_ledger from authenticated, anon'));
    expect(sql, contains('revoke insert, update, delete on public.gift_sends from authenticated, anon'));
    expect(sql, contains('revoke insert, update, delete on public.conversations, public.messages from authenticated, anon'));
    expect(sql, contains('revoke insert, update, delete on public.profiles from authenticated, anon'));
  });

  test('ledger is append-only and balances cannot go negative', () {
    expect(sql, contains('coin_ledger is append-only'));
    expect(sql, contains('coins bigint not null default 0 check (coins >= 0)'));
    expect(sql, contains('rewards bigint not null default 0 check (rewards >= 0)'));
  });

  test('gift sending is idempotent and locks wallets', () {
    expect(sql, contains('unique (sender_id, idempotency_key)'));
    expect(sql, contains('on conflict (sender_id, idempotency_key) do nothing'));
    expect(sql, contains('for update'));
  });

  test('every function is SECURITY DEFINER with a fixed search_path or is a pure helper', () {
    final fns = RegExp(r'create or replace function public\.(\w+)\(([\s\S]*?)\n\$\$;', multiLine: true).allMatches(sql);
    expect(fns.length, greaterThan(20));
    for (final m in fns) {
      final name = m.group(1)!;
      final body = m.group(0)!;
      if (name == 'feature_similarity' || name == 'ledger_immutable') continue;
      expect(body.contains('security definer'), isTrue, reason: '$name not security definer');
      expect(body.contains('set search_path = public'), isTrue, reason: '$name has no search_path');
    }
  });

  test('admin functions check admin rights', () {
    for (final f in ['admin_list_reports', 'admin_resolve_report', 'admin_set_ban', 'admin_set_setting', 'admin_grant_coins', 'admin_stats']) {
      final m = RegExp('function public\\.$f\\([\\s\\S]*?\\n\\\$\\\$;').firstMatch(sql);
      expect(m, isNotNull, reason: f);
      expect(m!.group(0)!.contains('is_admin()'), isTrue, reason: '$f missing is_admin()');
    }
  });

  test('chat requires similarity threshold, 18+ confirmation and block checks', () {
    expect(sql, contains("raise exception 'not_similar_enough'"));
    expect(sql, contains('age_confirmed'));
    expect(sql, contains('public.is_blocked(auth.uid(), other)'));
  });

  test('no real-money or PayPal logic is present in this migration', () {
    expect(sql.toLowerCase().contains('paypal'), isFalse);
    expect(sql.toLowerCase().contains('payout'), isFalse);
  });
}
