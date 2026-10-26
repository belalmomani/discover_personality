import 'dart:io';

import 'package:discover_personality/data/social/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/20260107000000_push_moderation.sql').readAsStringSync();
  final edge = File('supabase/functions/push-notify/index.ts').readAsStringSync();

  group('push + moderation migration (static checks)', () {
    test('push_tokens and blocked_terms are internal: RLS on, no policies, no client grants', () {
      for (final t in ['push_tokens', 'blocked_terms']) {
        expect(sql, contains('alter table public.$t enable row level security'));
        expect(sql, contains('revoke all on public.$t from authenticated, anon'));
      }
      expect(sql.contains('create policy'), isFalse);
    });

    test('every function is SECURITY DEFINER with a fixed search_path', () {
      final fns = RegExp(r'create or replace function public\.(\w+)\(([\s\S]*?)\n\$\$;').allMatches(sql).toList();
      expect(fns.length, 13);
      for (final m in fns) {
        expect(m.group(0)!.contains('security definer'), isTrue, reason: m.group(1));
        expect(m.group(0)!.contains('set search_path = public'), isTrue, reason: m.group(1));
      }
    });

    test('filter helpers are internal-only; admin functions check admin rights', () {
      expect(sql, contains('revoke all on function public.message_allowed(text) from public, anon, authenticated'));
      expect(sql, contains('revoke all on function public.messages_content_guard() from public, anon, authenticated'));
      for (final f in ['admin_list_terms', 'admin_add_term', 'admin_remove_term', 'admin_set_setting', 'admin_list_reports']) {
        final m = RegExp('function public\\.$f\\([\\s\\S]*?\\n\\\$\\\$;').firstMatch(sql);
        expect(m, isNotNull, reason: f);
        expect(m!.group(0)!.contains('is_admin()'), isTrue, reason: '$f missing is_admin()');
      }
    });

    test('text messages are filtered by a server-side trigger (blocked terms and optional link blocking)', () {
      expect(sql, contains('create trigger trg_messages_content_guard before insert on public.messages'));
      expect(sql, contains("return 'content_blocked'"));
      expect(sql, contains("return 'links_blocked'"));
      expect(sql, contains("public.setting_int('block_links', 0) = 1"));
      expect(sql, contains("k = 'block_links' and v::integer > 1"));
    });

    test('delivered status: set on load, implied by read', () {
      expect(sql, contains('add column if not exists delivered_at timestamptz'));
      expect(sql, contains('delivered_at = coalesce(m.delivered_at, now())'));
      expect(sql, contains('create or replace function public.mark_delivered()'));
    });

    test('push registration is validated and capped per user', () {
      expect(sql, contains("raise exception 'invalid_token'"));
      expect(sql, contains('limit 10'));
      expect(sql, contains('push_enabled = true'));
    });

    test('admin_list_reports is dropped before being recreated with the new column', () {
      expect(sql.indexOf('drop function if exists public.admin_list_reports(text)'), lessThan(sql.indexOf('create or replace function public.admin_list_reports')));
      expect(sql, contains('reports_against integer'));
      expect(sql, contains("case when m.kind = 'image' then '[صورة]' else m.body end")); // never leak a file path to the admin list
    });
  });

  test('re-running ALL migrations is safe: any function whose return type changes is dropped first, in every file', () {
    final files = Directory('supabase/migrations').listSync().whereType<File>().where((f) => f.path.endsWith('.sql')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final defs = <String, List<({String file, String ret, int pos, String text})>>{};
    for (final f in files) {
      final text = f.readAsStringSync();
      for (final m in RegExp(r'create or replace function public\.(\w+)\(([^)]*)\)\s*returns\s+(table \([^)]*\)|[\w ]+?)\s+language').allMatches(text)) {
        final key = '${m.group(1)}(${m.group(2)!.replaceAll(RegExp(r'\s+'), ' ')})';
        defs.putIfAbsent(key, () => []).add((file: f.path, ret: m.group(3)!.replaceAll(RegExp(r'\s+'), ' '), pos: m.start, text: text));
      }
    }
    for (final e in defs.entries) {
      final changes = e.value.map((d) => d.ret).toSet().length > 1;
      if (!changes) continue;
      final name = e.key.split('(').first;
      for (var i = 0; i < e.value.length; i++) {
        final d = e.value[i];
        // The first definition must be droppable on a re-run (the DB may hold a later, different version);
        // later ones only when their return type differs from the previous version.
        final needsDrop = i == 0 || d.ret != e.value[i - 1].ret;
        if (!needsDrop) continue;
        final before = d.text.substring(0, d.pos);
        expect(before.contains('drop function if exists public.$name('), isTrue, reason: '${e.key} in ${d.file} must be dropped first');
      }
    }
  });

  group('push Edge Function (static checks)', () {
    test('only the database webhook can call it, and no secret is hard-coded', () {
      expect(edge, contains('x-webhook-secret'));
      expect(edge, contains('PUSH_WEBHOOK_SECRET'));
      expect(edge.contains('BEGIN PRIVATE KEY----- '), isFalse);
      expect(RegExp(r'AIza[0-9A-Za-z_\-]{20,}').hasMatch(edge), isFalse);
      expect(edge, contains('SUPABASE_SERVICE_ROLE_KEY')); // read from the server environment only
      expect(edge, contains('FCM_SERVICE_ACCOUNT'));
    });

    test('notification text never includes the message body', () {
      final bodyLines = edge.split('\n').where((l) => l.contains('const text =')).join(' ');
      expect(bodyLines.contains('m.body'), isFalse);
      expect(edge.contains('record.body'), isFalse);
      expect(edge, contains('رسالة جديدة من'));
    });

    test('respects receiver settings, blocks and bans; removes dead tokens', () {
      for (final s in ['push_enabled', 'prof.banned', 'allow_chat', '"blocks"', 'UNREGISTERED']) {
        expect(edge, contains(s), reason: s);
      }
    });
  });

  test('model and message updates', () {
    final m = ChatMessage.fromJson({
      'id': 'a', 'conversation_id': 'c', 'sender_id': 'u', 'kind': 'text', 'body': 'x', 'created_at': '2026-01-01T10:00:00Z',
      'delivered_at': '2026-01-01T10:00:05Z', 'read_at': null,
    });
    expect(m.isDelivered, isTrue);
    expect(m.isRead, isFalse);
    final r = ChatMessage.fromJson({'id': 'b', 'conversation_id': 'c', 'sender_id': 'u', 'kind': 'text', 'body': 'x', 'created_at': '2026-01-01T10:00:00Z', 'read_at': '2026-01-01T10:01:00Z'});
    expect(r.isDelivered, isTrue); // read implies delivered
    final n = ChatMessage.fromJson({'id': 'c', 'conversation_id': 'c', 'sender_id': 'u', 'kind': 'text', 'body': 'x', 'created_at': '2026-01-01T10:00:00Z'});
    expect(n.isDelivered, isFalse);
    final rep = ReportRow.fromJson({'id': 'r', 'reporter': 'a', 'reported_id': 'u', 'reported': 'b', 'message_body': null, 'reason': 'x', 'status': 'open', 'created_at': '2026-01-01T10:00:00Z', 'reports_against': 3});
    expect(rep.reportsAgainst, 3);
    expect(socialErrorMessage(Exception('content_blocked')), contains('كلمات غير مسموحة'));
    expect(socialErrorMessage(Exception('links_blocked')), contains('الروابط'));
  });
}
