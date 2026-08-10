/// Static detection tables used by `DeviceIntegrity`.
///
/// Kept apart from the engine so a host app can review, extend or trim the
/// lists without touching detection logic. Everything here is `const`.
///
/// The tables are split by **confidence**, not just by field, because that is
/// what the scoring in `device_signal.dart` consumes: a name in
/// [emulatorNames] blocks on its own, a value in [ambiguousExactValues] only
/// counts as corroboration.
abstract final class DeviceFingerprints {
  /// Names distinctive enough to match *anywhere* inside any `Build` property
  /// and to block on their own.
  ///
  /// Only put strings here that cannot plausibly appear on retail hardware.
  /// Short, ambiguous names belong in [ambiguousExactValues] instead.
  static const Set<String> emulatorNames = {
    'bluestacks',
    'ldplayer',
    'noxplayer',
    'genymotion',
    'genymobile',
    'droid4x',
    'virtualbox',
    'vbox86',
    'vmware',
    'goldfish',
    'ranchu',
    'android_x86',
    'android-x86',
    'ttvm',
    'koplayer',
    'windroy',
    'microvirt',
    'tiantianvm',
    'waydroid',
    'anbox',
    'emulator',
    'simulator',
    'google_sdk',
    'sdk_gphone',
    'android sdk built for',
    'phoenix os',
    'primeos',
    'bignox',
    'nemu',
  };

  /// Short names matched *exactly* against `hardware`, `board` and `product`,
  /// strong enough to block on their own.
  ///
  /// Substring matching on these would false-positive on real hardware
  /// (`nox` inside an unrelated model name), hence the exact match.
  static const Set<String> emulatorExactValues = {
    'nox',
    'memu',
    'vbox',
    'qemu',
    'mumu',
    'andy',
    'ttvm',
  };

  /// Values that show up on emulators **and** on genuine retail devices, so
  /// they only count as corroboration ([SignalWeight.weak]).
  ///
  /// - `intel` / `x86` — Intel Atom phones (Asus Zenfone 2, Zenfone 5) report
  ///   these as `Build.HARDWARE`.
  /// - `cancro` — Nox uses it, but it is also the genuine codename of the
  ///   Xiaomi Mi 4.
  static const Set<String> ambiguousExactValues = {
    'intel',
    'x86',
    'cancro',
  };

  /// `Build.PRODUCT` values shipped by AOSP/Google emulator images.
  static const Set<String> emulatorProducts = {
    'sdk',
    'sdk_x86',
    'sdk_google',
    'sdk_google_phone_x86',
    'full_x86',
    'vbox86p',
    'vbox86tp',
  };

  /// Non-retail `Build.TYPE` values.
  static const Set<String> nonRetailBuildTypes = {'userdebug', 'eng'};

  /// Files that only exist inside an emulator / app-player image.
  /// Key is the path, value is the label used in the signal string.
  static const Map<String, String> emulatorArtifacts = {
    // MEmu / Droid4X
    '/system/bin/microvirtd': 'memu',
    '/system/lib/libdroid4x.so': 'droid4x',
    // Nox
    '/system/bin/nox-prop': 'nox',
    '/system/bin/noxd': 'nox',
    '/system/bin/nox-vbox-sf': 'nox',
    // LDPlayer
    '/system/bin/ldinit': 'ldplayer',
    '/system/bin/ldmountsf': 'ldplayer',
    // BlueStacks
    '/system/lib/libbluestacksHook.so': 'bluestacks',
    '/system/lib/libbstfolder_jni.so': 'bluestacks',
    '/system/xbin/bstk': 'bluestacks',
    '/data/bluestacks.prop': 'bluestacks',
    // Genymotion / AndroVM
    '/system/bin/androVM-prop': 'genymotion',
    '/system/bin/androVM_setprop': 'genymotion',
    '/dev/socket/genyd': 'genymotion',
    '/dev/socket/baseband_genyd': 'genymotion',
    // QEMU / AOSP emulator
    '/dev/qemu_pipe': 'qemu',
    '/dev/socket/qemud': 'qemu',
    '/system/bin/qemu-props': 'qemu',
    '/system/lib/libc_malloc_debug_qemu.so': 'qemu',
    '/sys/qemu_trace': 'qemu',
    // VirtualBox
    '/system/lib/vboxguest.ko': 'virtualbox',
    '/system/lib/vboxsf.ko': 'virtualbox',
    // Windroy (Android on Windows)
    '/system/bin/windroyed': 'windroy',
    // TianTian
    '/system/etc/init.tiantianvm.sh': 'tiantian',
  };

  /// Files that indicate root.
  ///
  /// Best effort only — most are unreadable to an unprivileged app on modern
  /// Android, which is why `safe_device`'s native check runs alongside this.
  static const Map<String, String> rootArtifacts = {
    '/system/app/Superuser.apk': 'superuser',
    '/sbin/su': 'su',
    '/system/bin/su': 'su',
    '/system/xbin/su': 'su',
    '/system/sd/xbin/su': 'su',
    '/system/bin/failsafe/su': 'su',
    '/data/local/su': 'su',
    '/data/local/bin/su': 'su',
    '/data/local/xbin/su': 'su',
    '/su/bin/su': 'su',
    '/sbin/.magisk': 'magisk',
    '/data/adb/magisk': 'magisk',
    '/system/bin/magisk': 'magisk',
    '/system/xbin/daemonsu': 'daemonsu',
  };

  /// Files that only a jailbroken iOS device exposes to a sandboxed app.
  ///
  /// On a stock device the sandbox denies every one of these, which the probe
  /// reports as "absent" — so a hit really does mean the sandbox is gone.
  /// Deliberately excludes `/bin/sh` and `/etc/hosts`, which are readable in
  /// contexts that are not jailbreaks.
  static const Map<String, String> jailbreakArtifacts = {
    '/Applications/Cydia.app': 'cydia',
    '/Applications/Sileo.app': 'sileo',
    '/Applications/Zebra.app': 'zebra',
    '/private/var/lib/cydia': 'cydia',
    '/private/var/lib/apt': 'apt',
    '/private/var/stash': 'stash',
    '/private/var/binpack': 'palera1n',
    '/var/checkra1n.dmg': 'checkra1n',
    '/usr/sbin/sshd': 'sshd',
    '/usr/libexec/ssh-keysign': 'ssh',
    '/usr/lib/libjailbreak.dylib': 'libjailbreak',
    '/Library/MobileSubstrate/MobileSubstrate.dylib': 'substrate',
    '/Library/MobileSubstrate/DynamicLibraries': 'substrate',
    '/bin/bash': 'bash',
  };

  /// Prefixes of `utsname.machine` on genuine iOS hardware (`iPhone14,5`).
  /// The Simulator reports the host architecture instead (`x86_64`, `arm64`).
  static const Set<String> iosMachinePrefixes = {'iphone', 'ipad', 'ipod'};

  /// Installer package names that count as a legitimate distribution channel.
  /// Matched as a substring of the reported store, lower-cased.
  static const Set<String> trustedInstallerStores = {
    'com.android.vending', // Google Play
    'com.google.android.feedback', // Play, older devices
    'com.sec.android.app.samsungapps', // Galaxy Store
    'com.huawei.appmarket', // AppGallery
    'com.amazon.venezia', // Amazon Appstore
    'com.apple.appstore',
    'com.apple.testflight',
  };
}
