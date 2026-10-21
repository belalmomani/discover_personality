import 'package:discover_personality/app/providers.dart';
import 'package:discover_personality/data/repositories/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalStore> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return LocalStore(await SharedPreferences.getInstance());
  }

  test('extra results persist across restarts and keep the latest per test', () async {
    final s = await fresh();
    final n = ExtraResultsNotifier(s);
    await n.save('bigfive', {1: 3, 2: 4});
    await n.save('bigfive', {1: 5, 2: 5});
    await n.save('eq', {1: 1});
    final back = ExtraResultsNotifier(s).state;
    expect(back.keys.toSet(), {'bigfive', 'eq'});
    expect(back['bigfive']!.answers, {1: 5, 2: 5});
  });

  test('profile (birth date + country) persists and clears with user data', () async {
    final s = await fresh();
    final n = ProfileNotifier(s);
    await n.setBirthDate(DateTime(1985, 12, 19, 13, 45));
    await n.setCountry('JO');
    final back = ProfileNotifier(s).state;
    expect(back.birthDate, DateTime(1985, 12, 19));
    expect(back.countryCode, 'JO');
    await s.clearUserData();
    expect(ProfileNotifier(s).state.birthDate, isNull);
    expect(ExtraResultsNotifier(s).state, isEmpty);
  });

  test('corrupt profile/extra data is ignored', () async {
    SharedPreferences.setMockInitialValues({'profile.v1': 'x', 'extra.v1': '[1]'});
    final s = LocalStore(await SharedPreferences.getInstance());
    expect(s.loadProfile().birthDate, isNull);
    expect(s.loadExtra(), isEmpty);
  });

  test('unfinished additional-test progress persists, is per test, and clears on finish / user data deletion', () async {
    final s = await fresh();
    final n = ExtraProgressNotifier(s);
    await n.setAnswer('bigfive', 1, 4);
    await n.setAnswer('bigfive', 2, 2);
    await n.setAnswer('eq', 1, 5);
    var back = ExtraProgressNotifier(s).state;
    expect(back['bigfive'], {1: 4, 2: 2});
    expect(back['eq'], {1: 5});
    await n.clearTest('bigfive');
    back = ExtraProgressNotifier(s).state;
    expect(back.containsKey('bigfive'), isFalse);
    expect(back['eq'], {1: 5});
    await s.clearUserData();
    expect(ExtraProgressNotifier(s).state, isEmpty);
  });

  test('invalid progress values are rejected and corrupt data is ignored', () async {
    final s = await fresh();
    await expectLater(ExtraProgressNotifier(s).setAnswer('eq', 1, 9), throwsArgumentError);
    SharedPreferences.setMockInitialValues({'extra_progress.v1': '{"eq":{"1":9}}'});
    final s2 = LocalStore(await SharedPreferences.getInstance());
    expect(s2.loadExtraProgress(), isEmpty);
  });
}
