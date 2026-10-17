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
}
