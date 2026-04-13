import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/auth/credential_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saves loads and clears zhengfang credentials', () async {
    final store = CredentialStore.instance;

    await store.saveCredentials('20250001', 'secret');
    expect(await store.loadCredentials(), ('20250001', 'secret'));

    await store.clearCredentials();
    expect(await store.loadCredentials(), isNull);
  });

  test('persists independent auth sessions', () async {
    final store = CredentialStore.instance;

    await store.saveZhengfangSession('20250001');
    await store.saveUnifiedAuthSession('u20250001');

    expect(await store.loadZhengfangSession(), '20250001');
    expect(await store.loadUnifiedAuthSession(), 'u20250001');

    await store.clearZhengfangSession();
    expect(await store.loadZhengfangSession(), isNull);
    expect(await store.loadUnifiedAuthSession(), 'u20250001');
  });
}
