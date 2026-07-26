// Unit tests for the "Delete account" flow (Phase 38, DEL-ACCOUNT).
//
// A ProviderContainer with authServiceProvider overridden to a fake — mirrors
// the container-override shape in test/unit/sync/delete_trips_controller_test.dart.
// No Firebase/GoogleSignIn/network involved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traevy/features/auth/providers/auth_providers.dart';
import 'package:traevy/features/auth/providers/delete_account_controller.dart';
import 'package:traevy/features/auth/services/auth_service.dart';
import 'package:traevy/sync/api_client.dart';

/// Scripted fake [AuthService] used only for [AuthService.deleteAccount].
/// Every other member is unreachable and surfaces via `noSuchMethod`.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.throwOnDelete = false});

  final bool throwOnDelete;
  int deleteAccountCallCount = 0;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCallCount++;
    if (throwOnDelete) throw const SyncException.transport();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer containerWith(_FakeAuthService service) {
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts at DeleteAccountIdle', () {
    final container = containerWith(_FakeAuthService());
    expect(
      container.read(deleteAccountControllerProvider),
      isA<DeleteAccountIdle>(),
    );
  });

  test('success path -> DeleteAccountSuccess', () async {
    final service = _FakeAuthService();
    final container = containerWith(service);

    await container
        .read(deleteAccountControllerProvider.notifier)
        .deleteAccount();

    expect(service.deleteAccountCallCount, 1);
    expect(
      container.read(deleteAccountControllerProvider),
      isA<DeleteAccountSuccess>(),
    );
  });

  test(
    'SyncException path -> DeleteAccountError, no rethrow',
    () async {
      final service = _FakeAuthService(throwOnDelete: true);
      final container = containerWith(service);

      // Must NOT throw out of deleteAccount() (errors caught internally).
      await container
          .read(deleteAccountControllerProvider.notifier)
          .deleteAccount();

      expect(
        container.read(deleteAccountControllerProvider),
        isA<DeleteAccountError>(),
      );
    },
  );

  test('in-progress double-call guard is a no-op', () async {
    final service = _FakeAuthService();
    final container = containerWith(service);
    final notifier = container.read(deleteAccountControllerProvider.notifier);

    final first = notifier.deleteAccount();
    final second = notifier.deleteAccount();
    await Future.wait([first, second]);

    // The guard checks `state is DeleteAccountInProgress` synchronously
    // before the first await point, so the second concurrent call must have
    // been skipped — deleteAccount() on the fake service runs only once.
    expect(service.deleteAccountCallCount, 1);
    expect(
      container.read(deleteAccountControllerProvider),
      isA<DeleteAccountSuccess>(),
    );
  });
}
