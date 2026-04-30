# App Updater

Reusable app update and maintenance guard.

## Usage

```dart
AppUpdaterGuard(
  provider: RestfulAppUpdaterProvider(url: updateManifestUrl),
  child: app,
)
```

Built-in providers:

```dart
// Remote JSON endpoint.
RestfulAppUpdaterProvider(url: updateManifestUrl)
```

You can create your own provider for any data source by implementing
`AppUpdaterProvider`. Use this instead of the built-in REST, map, or asset
providers when your app needs Firebase Remote Config, secure storage, a custom
API client, a database, or any other source.

```dart
class FirebaseRemoteConfigAppUpdaterProvider extends AppUpdaterProvider {
  FirebaseRemoteConfigAppUpdaterProvider({required this.remoteConfig});

  final FirebaseRemoteConfig remoteConfig;

  @override
  Future<AppUpdaterDistributionManifest?> getDistributionManifest() async {
    await remoteConfig.fetchAndActivate();

    final payload = remoteConfig.getValue('app_updater_manifest').asString();
    final json = jsonDecode(payload) as Map<String, dynamic>;

    return AppUpdaterDistributionManifest.fromJson(json);
  }
}
```

Then pass it to the guard:

```dart
AppUpdaterGuard(
  provider: FirebaseRemoteConfigAppUpdaterProvider(
    remoteConfig: remoteConfig,
  ),
  child: app,
)
```

## Manifest Format

```json
{
  "android": {
    "version": {
      "minimum": "1.0.0",
      "latest": "1.2.0"
    },
    "download_url": "https://play.google.com/store/apps/details?id=com.example.app",
    "status": {
      "maintenance": false,
      "message": {
        "en": "A new version is available.",
        "ar": "يوجد تحديث جديد"
      }
    }
  },
  "ios": {
    "version": {
      "minimum": "1.0.0",
      "latest": "1.2.0"
    },
    "download_url": "https://apps.apple.com/app/id123456789",
    "status": {
      "maintenance": false,
      "message": {
        "en": "A new version is available."
      }
    }
  }
}
```

Supported platform keys are `android`, `ios` or `iOS`, `macos` or `macOS`,
`windows`, and `linux`.

## Status Rules

- `maintenance`: current platform status has `"maintenance": true`
- `forcedUpdate`: installed version is lower than `version.minimum`
- `outdated`: installed version is lower than `version.latest`
- `upToDate`: installed version is equal to or newer than `version.latest`
- `unknown`: manifest is unavailable, invalid, or missing the current platform

Messages are resolved by exact language code first, then base language, then
English, then the first available message.
