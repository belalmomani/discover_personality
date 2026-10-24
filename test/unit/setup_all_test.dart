import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// setup_all.sql must always equal the concatenation of the individual migrations (no drift).
void main() {
  const order = [
    'supabase/migrations/20260101000000_init.sql',
    'supabase/seed.sql',
    'supabase/migrations/20260102000000_social.sql',
    'supabase/migrations/20260103000000_similarity_v2.sql',
    'supabase/migrations/20260104000000_chat_images.sql',
    'supabase/migrations/20260105000000_similarity_cache.sql',
    'supabase/migrations/20260106000000_catalog_v2.sql',
  ];
  final all = File('supabase/setup_all.sql').readAsStringSync();

  test('setup_all.sql contains every file, in order, unchanged', () {
    var cursor = 0;
    for (final p in order) {
      final name = p.split('/').last;
      final body = File(p).readAsStringSync().trimRight();
      final begin = all.indexOf('-- ############ BEGIN $name ############', cursor);
      expect(begin, greaterThanOrEqualTo(0), reason: 'missing $name or out of order');
      final end = all.indexOf('-- ############ END $name ############', begin);
      expect(end, greaterThan(begin), reason: name);
      final section = all.substring(begin, end);
      expect(section.contains(body), isTrue, reason: '$name differs: rebuild with python3 tool/build_setup_sql.py');
      cursor = end;
    }
  });

  test('seed contains 72 questions and the init schema comes first', () {
    expect(RegExp(r"\n\s+\(\d+, '(mbti|enneagram|arfd)'").allMatches(all).length, 72);
    expect(all.indexOf('create table if not exists public.profiles'), lessThan(all.indexOf('insert into public.questions')));
    expect(all.indexOf('insert into public.questions'), lessThan(all.indexOf('create table if not exists public.admin_users')));
  });
}
