import 'dart:io';
import 'dart:typed_data';

import 'package:discover_personality/data/social/image_validator.dart';
import 'package:discover_personality/data/social/social_models.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(List<int> head, [int total = 64]) {
  final b = Uint8List(total);
  for (var i = 0; i < head.length; i++) {
    b[i] = head[i];
  }
  return b;
}

void main() {
  final sql = File('supabase/migrations/20260104000000_chat_images.sql').readAsStringSync();

  group('client-side image validation (real signature, not extension)', () {
    test('accepts JPEG, PNG and WebP', () {
      final jpg = validateChatImage(bytes([0xFF, 0xD8, 0xFF, 0xE0]));
      expect(jpg.ok, isTrue);
      expect(jpg.mime, 'image/jpeg');
      expect(jpg.ext, 'jpg');
      final png = validateChatImage(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
      expect(png.mime, 'image/png');
      expect(png.ext, 'png');
      final webp = validateChatImage(bytes([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]));
      expect(webp.mime, 'image/webp');
      expect(webp.ext, 'webp');
    });

    test('rejects dangerous or unsupported files even if renamed to .jpg', () {
      expect(validateChatImage(Uint8List.fromList('GIF89a....'.codeUnits)).error, 'unsupported_type');
      expect(validateChatImage(Uint8List.fromList('<svg xmlns="http://www.w3.org/2000/svg"></svg>'.codeUnits)).ok, isFalse);
      expect(validateChatImage(Uint8List.fromList('%PDF-1.7'.codeUnits)).ok, isFalse);
      expect(validateChatImage(Uint8List.fromList('MZ\x90\x00'.codeUnits)).ok, isFalse); // Windows executable
      expect(validateChatImage(Uint8List.fromList('<html><script>alert(1)</script>'.codeUnits)).ok, isFalse);
      expect(validateChatImage(bytes([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45])).ok, isFalse); // RIFF/WAVE
    });

    test('rejects empty and oversize files (limit is exactly 2 MB)', () {
      expect(validateChatImage(Uint8List(0)).error, 'empty');
      expect(validateChatImage(bytes([0xFF, 0xD8, 0xFF], chatImageMaxBytes)).ok, isTrue);
      expect(validateChatImage(bytes([0xFF, 0xD8, 0xFF], chatImageMaxBytes + 1)).error, 'too_large');
    });
  });

  group('storage path', () {
    const u = '11111111-1111-4111-8111-111111111111';
    const c = '22222222-2222-4222-8222-222222222222';
    const f = '33333333-3333-4333-8333-333333333333';

    RegExp serverRegex() {
      final m = RegExp(r"select p_name ~ '([^']+)';").firstMatch(sql)!;
      return RegExp(m.group(1)!);
    }

    test('generated paths satisfy the exact regex used by the server policies', () {
      for (final t in ChatImageType.values) {
        expect(serverRegex().hasMatch(chatImagePath(u, c, f, t)), isTrue, reason: '$t');
      }
    });

    test('path traversal and foreign extensions do not match the server regex', () {
      final r = serverRegex();
      expect(r.hasMatch('$u/$c/$f.svg'), isFalse);
      expect(r.hasMatch('$u/$c/$f.jpg.exe'), isFalse);
      expect(r.hasMatch('$u/../$c/$f.jpg'), isFalse);
      expect(r.hasMatch('$u/$c/x/$f.jpg'), isFalse);
      expect(r.hasMatch('$u/$c.jpg'), isFalse);
      expect(r.hasMatch('../$c/$f.jpg'), isFalse);
    });
  });

  group('migration (static checks)', () {
    test('private bucket with 2 MB limit and image-only mime types', () {
      expect(sql, contains("values ('chat-images', 'chat-images', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])"));
      expect(sql.contains("'image/gif'"), isFalse);
      expect(sql.contains('svg'), isFalse);
    });

    test('policies restrict upload, read and delete; no public access', () {
      expect(sql, contains('create policy chat_images_insert on storage.objects for insert to authenticated'));
      expect(sql, contains('create policy chat_images_select on storage.objects for select to authenticated'));
      expect(sql, contains('create policy chat_images_delete on storage.objects for delete to authenticated'));
      expect(sql, contains("split_part(p_name, '/', 1) <> auth.uid()::text")); // uploads only into your own folder
      expect(sql, contains('auth.uid() in (c.user_a, c.user_b)'));
      // whole-word matches only ("insert into public.messages" must not count as "to public")
      expect(RegExp(r'(^|\s)to\s+(anon|public)\b').hasMatch(sql), isFalse);
    });

    test('send_image_message re-checks the stored object, blocks, bans and rate limits', () {
      expect(sql, contains("raise exception 'invalid_image'"));
      expect(sql, contains('sz > 2097152'));
      expect(sql, contains("mt not in ('image/jpeg', 'image/png', 'image/webp')"));
      expect(sql, contains('public.is_blocked(auth.uid(), other)'));
      expect(sql, contains("raise exception 'banned'"));
      expect(sql, contains("raise exception 'rate_limited'"));
      expect(sql, contains("raise exception 'image_limit'"));
      expect(sql, contains("split_part(p_path, '/', 2) <> conv::text"));
    });

    test('message kind constraint allows images and functions are SECURITY DEFINER', () {
      expect(sql, contains("check (kind in ('text', 'gift', 'image'))"));
      final fns = RegExp(r'create or replace function public\.(\w+)\(([\s\S]*?)\n\$\$;').allMatches(sql).toList();
      expect(fns.length, 4);
      for (final m in fns) {
        if (m.group(1) == 'chat_image_path_ok') continue; // pure regex helper
        expect(m.group(0)!.contains('security definer'), isTrue, reason: m.group(1));
        expect(m.group(0)!.contains('set search_path = public'), isTrue, reason: m.group(1));
      }
    });
  });

  test('image error messages are friendly Arabic', () {
    expect(socialErrorMessage(StateError('invalid_image')), contains('2 ميجابايت'));
    expect(socialErrorMessage(Exception('image_limit')), contains('الحد الأقصى'));
  });
}
