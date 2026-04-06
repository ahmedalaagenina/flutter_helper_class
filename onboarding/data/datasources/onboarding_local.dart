import 'package:flutter/foundation.dart';
import 'package:idara_esign/core/constants/storage_keys.dart';
import 'package:idara_esign/core/security/secure_storage.dart';

abstract class IOnboardingLocalDataSource {
  Future<bool> isSeen();
  Future<void> setSeen(bool value);
  Future<void> reset();
}

class OnboardingLocal implements IOnboardingLocalDataSource {
  SecureStorage secureStorage;

  OnboardingLocal(this.secureStorage);

  @override
  Future<bool> isSeen() async {
    if (kIsWeb) return true;
    final value = await secureStorage.read(
      key: StorageKeys.onboardingCompleted,
    );
    return value == 'true';
  }

  @override
  Future<void> setSeen(bool value) async {
    await secureStorage.write(
      key: StorageKeys.onboardingCompleted,
      value: value.toString(),
    );
  }

  @override
  Future<void> reset() async => setSeen(false);
}
