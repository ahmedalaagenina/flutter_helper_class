# Networking Helper (Dio)

A complete, production-ready networking stack for Flutter built on top of [Dio](https://pub.dev/packages/dio).
It bundles authentication, retry with backoff, HTTP caching, offline write-queueing with auto-sync, duplicate-request protection, unified error handling, file upload/download, and a typed `Result`/`Either` wrapper for callers.

```
networking/
├── api_constant.dart                 # Base URL + endpoint paths
├── api_service.dart                  # Abstract API contract
├── api_service_impl.dart             # Dio-backed implementation
├── api_call_handler.dart             # handleRead / handleWrite + Result<T>
├── auth_interceptor.dart             # Token attach + 401 refresh
├── cache_service.dart                # Singleton cache store + options
├── duplicate_request_interceptor.dart# Drops duplicate in-flight requests
├── file_data.dart                    # Cross-platform file abstraction
├── method_type.dart                  # HTTP method enum
├── network_helper.dart               # Dio factory (wires interceptors)
├── network_info.dart                 # Connectivity check + stream
├── networking.dart                   # Barrel file (one import)
│
├── error/
│   ├── api_failure_helper.dart       # Maps any error → AppFailure
│   ├── app_exception.dart            # Sealed exceptions
│   └── app_failure.dart              # Sealed failures (UI-facing)
│
├── local_storage/
│   ├── auth_token_store.dart         # Volatile + secure token store
│   ├── hive_local_storage_api_service.dart
│   └── local_storage_api_service.dart
│
├── offline_sync/
│   ├── offline_sync_config.dart      # Queue policy/config
│   ├── offline_sync_interceptor.dart # Queues failed writes when offline
│   ├── queued_request.dart           # Hive-serializable request
│   ├── sync_event.dart               # UI events (started/failed/idle…)
│   ├── sync_queue.dart               # Persistent FIFO queue
│   └── sync_service_manager.dart     # Connectivity-aware replayer
│
└── retry/
    ├── retry_interceptor.dart        # Exponential backoff + jitter
    └── retry_options.dart            # Per-request overrides
```

Import everything with a single line:

```dart
import 'package:<your_app>/core/networking/networking.dart';
```

---

## Table of contents

1. [Features at a glance](#features-at-a-glance)
2. [Setup & dependency injection](#setup--dependency-injection)
3. [Feature reference](#feature-reference)
   - [1. ApiService (HTTP client facade)](#1-apiservice-http-client-facade)
   - [2. ApiCallHandler & Result&lt;T&gt;](#2-apicallhandler--resultt)
   - [3. AuthInterceptor (token + refresh)](#3-authinterceptor-token--refresh)
   - [4. RetryInterceptor (backoff + jitter)](#4-retryinterceptor-backoff--jitter)
   - [5. DioCacheInterceptor / CacheService](#5-diocacheinterceptor--cacheservice)
   - [6. DuplicateRequestInterceptor](#6-duplicaterequestinterceptor)
   - [7. OfflineSyncInterceptor + SyncServiceManager](#7-offlinesyncinterceptor--syncservicemanager)
   - [8. NetworkInfo](#8-networkinfo)
   - [9. AuthTokenStore](#9-authtokenstore)
   - [10. LocalStorageApiService (Hive)](#10-localstorageapiservice-hive)
   - [11. FileData & uploads/downloads](#11-filedata--uploadsdownloads)
   - [12. Error handling: AppException / AppFailure / ApiFailureHandler](#12-error-handling-appexception--appfailure--apifailurehandler)
4. [End-to-end recipes](#end-to-end-recipes)

---

## Features at a glance

| # | Feature | When to use |
|---|---------|-------------|
| 1 | **ApiService** | Every HTTP call (GET/POST/PUT/PATCH/DELETE/HEAD, download, multipart) |
| 2 | **ApiCallHandler / Result** | Repository layer — converts thrown errors into typed `Either<AppFailure, T>` |
| 3 | **AuthInterceptor** | Anytime an endpoint needs `Authorization: Bearer …` or 401-refresh-and-retry |
| 4 | **RetryInterceptor** | Flaky networks, 5xx, 429, timeouts — auto retry with exponential backoff |
| 5 | **CacheService / DioCacheInterceptor** | Read endpoints you want cached on disk for offline / faster repeats |
| 6 | **DuplicateRequestInterceptor** | Prevents double-tap submissions hitting the server twice |
| 7 | **OfflineSync** | Persist write requests when offline and replay them when back online |
| 8 | **NetworkInfo** | Check connectivity before a call or react to connectivity changes |
| 9 | **AuthTokenStore** | Save/load the auth token (volatile + secure storage, persistent vs session) |
| 10 | **LocalStorageApiService** | Hive wrapper to cache structured JSON responses (alt. to HTTP cache) |
| 11 | **FileData** | Upload / multipart with one model across mobile, web bytes, and `blob:` URLs |
| 12 | **AppException / AppFailure** | Show user-friendly errors, branch UI on failure types |

---

## Setup & dependency injection

The stack is designed to be wired through `GetIt` (or any DI container). The
suggested order — copy this into your `service_locator.dart`:

```dart
Future<void> _registerNetworkStack() async {
  // 1. Cache store (Hive)
  await CacheService.instance.init();

  // 2. Offline sync queue (Hive)
  final syncQueue = SyncQueue();
  await syncQueue.init();
  getIt.registerLazySingleton<SyncQueue>(() => syncQueue);

  // 3. Misc helpers
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  getIt.registerFactory(() => CancelToken());

  // 4. Auth token store (depends on SecureStorage + SharedPreferences)
  getIt.registerLazySingleton<AuthTokenStore>(
    () => AuthTokenStoreImpl(
      secureStorage: getIt(),
      sharedPreferences: getIt(),
    ),
  );

  // 5. Dio (async because it awaits Hive)
  getIt.registerSingletonAsync<Dio>(
    () async => await NetworkHelper(
      getIt<AuthTokenStore>(),
      getIt<SharedPreferences>(),
      syncQueue: syncQueue,
    ).createDio(),
  );

  // 6. ApiService (depends on Dio being ready)
  getIt.registerSingletonWithDependencies<ApiService>(
    () => ApiServiceImpl(getIt<Dio>()),
    dependsOn: [Dio],
  );

  // 7. Sync manager — starts replaying the queue when online
  getIt.registerSingletonWithDependencies<SyncServiceManager>(
    () => SyncServiceManager(
      dio: getIt<Dio>(),
      queue: getIt<SyncQueue>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
    dependsOn: [Dio],
  );

  await getIt.isReady<Dio>();
  await getIt.isReady<ApiService>();
  await getIt.isReady<SyncServiceManager>();

  // Start listening to connectivity
  getIt<SyncServiceManager>().init();
}
```

In `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();          // required for cache + sync queue
  await setupServiceLocator();
  await getIt.allReady();
  runApp(const MyApp());
}
```

> **Order of interceptors matters.** [network_helper.dart](network_helper.dart) wires them in this exact order:
> `DuplicateRequest → Auth → Cache → Retry → OfflineSync → Logger`.
> Duplicates die first; auth attaches the token; cache short-circuits reads; retry exhausts attempts; offline-sync only queues if everything above failed.

---

## Feature reference

### 1. ApiService (HTTP client facade)

[api_service.dart](api_service.dart) defines the contract, [api_service_impl.dart](api_service_impl.dart) provides the Dio-backed implementation.

**When to use**
- Every HTTP call in the app. Repositories depend on `ApiService`, not on `Dio` directly.

**Power**
- One uniform API for `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `download`, and `multipartRequest`.
- Accepts per-request `RetryOptions` and `CacheOptions` — overrides the global defaults without touching the Dio instance.
- `multipartRequest` accepts a `Map<String, FileData>` so you can upload from a file path, raw bytes, or a `blob:` URL with the same call.
- All `recreateFormData` logic is stashed in `options.extra` so the retry interceptor can rebuild the body on retry (FormData is single-shot in Dio).

**Weakness**
- Returns raw `Response<T>` — you still need a JSON parser around it. Pair it with `ApiCallHandler.handleRead/handleWrite` to get a `Result<T>` instead.
- The abstract surface is wide; if you only need GET/POST, you carry the rest with you.

**How to use**

```dart
final api = getIt<ApiService>();

// Simple GET
final res = await api.get<Map<String, dynamic>>(ApiConstant.userProfile);

// POST with retry override + progress
final res2 = await api.post<Map<String, dynamic>>(
  '/trips',
  data: {'origin': 'A', 'destination': 'B'},
  retryOptions: RetryOptions(
    maxRetries: 5,
    retryDelay: const Duration(seconds: 2),
  ),
  onSendProgress: (sent, total) => print('${(sent / total * 100).toInt()}%'),
);

// Cancel an in-flight request
final cancelToken = CancelToken();
api.post('/upload', data: data, cancelToken: cancelToken);
// ...later
cancelToken.cancel('User cancelled');
```

---

### 2. ApiCallHandler & `Result<T>`

[api_call_handler.dart](api_call_handler.dart) — `handleRead` for queries, `handleWrite` for mutations.

**When to use**
- In the **repository / data source** layer. Wrap every remote call so the bloc/UI only sees `Result<T>` (success / failure / offline-queued / from-cache).

**Power**
- Returns `Result<T>` with three signals:
  - `isSuccess` / `isFailure`
  - `source` (`remote`, `cache`, `offlineQueued`)
  - `failure` (typed `AppFailure` — branch UI on it)
- `handleRead` first checks `NetworkInfo`; if offline it serves cached data (when you pass `getCachedData`) instead of throwing.
- `handleWrite` automatically:
  - Silently drops `DuplicateRequestFailure` (so the bloc never emits a spurious error from a double-tap).
  - Detects offline errors, runs `optimisticCacheCall`, and returns `OfflineQueuedFailure` carrying a `syncId` — so the UI can show "queued, will sync".
- Plugs straight into `Either<AppFailure, T>` (from `dartz`) for FP-style branching.

**Weakness**
- Requires `dartz` as a dependency.
- The `optimisticCacheCall` only fires when `OfflineSyncConfig.returnSyntheticResponse` is `false` — easy footgun if you flip that flag and forget.
- Two callbacks (`cacheCall` for success, `getCachedData` for offline read) — two places to keep in sync.

**How to use**

```dart
// Read with cache fallback
Future<Result<UserProfile>> getProfile() {
  return ApiCallHandler.handleRead<UserProfile>(
    networkInfo: getIt<NetworkInfo>(),
    remoteCall: () async {
      final res = await api.get(ApiConstant.userProfile);
      return UserProfile.fromJson(res.data);
    },
    cacheCall: (profile) => _localDb.save(
      key: 'profile',
      data: profile.toJson(),
    ),
    getCachedData: () async {
      final json = _localDb.read('profile');
      return json == null ? null : UserProfile.fromJson(json);
    },
  );
}

// Write with optimistic cache + offline queue
Future<Result<Trip>> createTrip(Trip trip) {
  return ApiCallHandler.handleWrite<Trip>(
    remoteCall: () async {
      final res = await api.post('/trips', data: trip.toJson());
      return Trip.fromJson(res.data);
    },
    cacheCall: (saved) => _localDb.save(key: 'trip-${saved.id}', data: saved.toJson()),
    optimisticCacheCall: () => _localDb.save(
      key: 'trip-pending-${trip.localId}',
      data: trip.toJson(),
    ),
  );
}

// Bloc usage
final result = await repo.getProfile();
if (result.isSuccess) emit(Loaded(result.value!, fromCache: result.isFromCache));
else if (result.failure is OfflineQueuedFailure) emit(Queued());
else emit(Error(result.failure!.message));
```

---

### 3. AuthInterceptor (token + refresh)

[auth_interceptor.dart](auth_interceptor.dart) — `QueuedInterceptor` that attaches the bearer token, refreshes on 401/403, and triggers logout when refresh fails.

**When to use**
- Any app with bearer-token auth and a refresh-token endpoint.

**Power**
- Auto-attaches `Authorization: Bearer …` on every request that isn't login/verify-OTP.
- Auto-attaches `Accept-Language` from `SharedPreferences`.
- **Single-flight refresh:** if 10 concurrent requests get 401, only one refresh call goes out; the rest await the same `Completer`.
- **Stale-token detection:** if another request already refreshed the token mid-flight, the failed request re-fetches with the new one instead of triggering a second refresh.
- **One-shot logout:** once refresh fails, `_forceLogout = true` short-circuits all subsequent 401s — no cascade of refresh+logout cycles.
- Resets state on login/register requests automatically.

**Weakness**
- Hardcoded refresh response shape (`data?['data']?['token']`) — adjust `_doRefreshToken` if your backend differs.
- Hardcoded "login"/"verify"/"logout" paths via `ApiConstant.*` — endpoints outside that list are assumed protected.

**How to use**

Wire the forced-logout callback through `NetworkHelper` — anything you can call (bloc event, navigator, callback) works:

```dart
NetworkHelper(
  tokenStore,
  prefs,
  syncQueue: syncQueue,
  onForceLogout: () => getIt<AuthBloc>().add(const LogoutEvent()),
).createDio();
```

---

### 4. RetryInterceptor (backoff + jitter)

[retry_interceptor.dart](retry/retry_interceptor.dart) + [retry_options.dart](retry/retry_options.dart).

**When to use**
- Always (it's wired by default). Override per-request when a specific endpoint needs more/fewer attempts.

**Power**
- Retries on: connection timeout, `SocketException`, HTTP 429, and 5xx **on safe methods only** (`GET/PUT/DELETE/HEAD/OPTIONS`).
- POST is **not** retried on `receiveTimeout` — the request may have hit the server and you don't want a duplicate side effect.
- Exponential backoff (`baseDelay * 2^attempt`) with 50–100 % jitter, capped at `maxDelay` (default 30 s).
- Honors `Retry-After` header (both seconds and HTTP-date).
- Per-request override via `RetryOptions` parameter on `ApiService` methods (stored in `options.extra`).
- **Rebuilds `FormData` on retry** by calling the stashed `recreateFormData` closure — fixes Dio's "FormData can only be sent once" issue.

**Weakness**
- Default `maxRetries=3` means a flaky link can stretch a request to ~14 s (`1+2+4+...` with jitter). Tune for your UX.
- Retries delay the user's perception of failure — the spinner stays on screen during retries.
- No circuit-breaker; if the server is genuinely down, every call burns 3 attempts.

**How to use**

Global (via `NetworkHelper.createDio`):

```dart
NetworkHelper(tokenStore, prefs, syncQueue: queue).createDio(
  defaultMaxRetries: 3,
  defaultRetryDelay: const Duration(seconds: 2),
);
```

Per request:

```dart
await api.get('/heavy-report',
  retryOptions: RetryOptions(
    maxRetries: 5,
    retryDelay: const Duration(seconds: 4),
  ),
);
```

---

### 5. DioCacheInterceptor / CacheService

[cache_service.dart](cache_service.dart) — singleton over `dio_cache_interceptor` + `http_cache_hive_store`.

**When to use**
- Read endpoints where stale data is acceptable for the offline / slow-network case.
- When you want **automatic** cache fallback on network failure (no extra repository code).

**Power**
- Default policy: `refreshForceCache` — always tries network first, falls back to cache on failure, with `maxStale: 7 days`.
- `hitCacheOnNetworkFailure: true` — failing fetch returns cached data instead of an error.
- Per-request `buildOptions(...)` for custom policies (e.g., `CachePolicy.request` for fresh reads, `allowPostMethod: true` for cached POST searches).
- Stored in the OS **temporary directory** — survives app restarts, cleared by the OS under pressure.
- Manual control: `clearAll()`, `clearForKey(key)`, `clearForPath(RegExp)`.

**Weakness**
- Caches `Response` — not parsed models. The model is rebuilt on every read.
- `hitCacheOnNetworkFailure` returns the **whole** cached payload — you can't merge fresh + cached.
- `clearForPath` only works against `HiveCacheStore` (current store).
- Tied to Hive — adds the `path_provider` + `http_cache_hive_store` deps.
- For structured offline reads of *parsed* models, prefer [LocalStorageApiService](#10-localstorageapiservice-hive) + `handleRead.getCachedData`.

**How to use**

```dart
// Default (already wired)
await api.get('/home');

// Per-request override: fresh-only, 1-hour stale window
final res = await api.get(
  '/news/feed',
  cacheOptions: CacheService.instance.buildOptions(
    policy: CachePolicy.request,
    maxStale: const Duration(hours: 1),
  ),
);

// Clear after logout
await CacheService.instance.clearAll();

// Clear a specific endpoint
await CacheService.instance.clearForPath(RegExp(r'/user/.*'));
```

---

### 6. DuplicateRequestInterceptor

[duplicate_request_interceptor.dart](duplicate_request_interceptor.dart).

**When to use**
- Always (it's wired first). Stops accidental double-submits (rapid taps, navigation races) from hitting the server twice.

**Power**
- Tracks in-flight requests by a canonical signature: `METHOD:URI:canonicalized-JSON-payload`.
- Map keys are sorted (via `SplayTreeMap`) so `{a:1, b:2}` and `{b:2, a:1}` collide.
- Only intercepts mutating methods — `GET/HEAD/OPTIONS` always pass through.
- Skips `FormData` (uploads aren't reliably hashable).
- Rejects the duplicate with `DioExceptionType.cancel` and a sentinel `duplicateMessage`; `ApiCallHandler.handleWrite` recognizes it and returns `DuplicateRequestFailure`, which `BaseBloc.safeHandle` silently ignores. **No spurious error toast for the user.**

**Weakness**
- In-memory only — restarting the app clears the registry.
- File uploads (`FormData`) are not deduped.
- Two requests that differ only by a server-side timestamp in the body are treated as different (correct, but be aware).
- If a request hangs forever and is never resolved/rejected, the signature stays in the set — but that scenario only occurs with broken downstream interceptors.

**How to use**

Zero-config; just submit forms normally:

```dart
// User taps submit 5x quickly:
for (var i = 0; i < 5; i++) {
  // Only the 1st actually goes out; the other 4 are
  // rejected with DuplicateRequestFailure and swallowed.
  await api.post('/orders', data: order.toJson());
}
```

---

### 7. OfflineSyncInterceptor + SyncServiceManager

[offline_sync/](offline_sync/).

**When to use**
- Apps that must accept **writes** while offline (chat send, form submit, status update) and replay them when connectivity returns.

**Power**
- **Persistent queue** (`SyncQueue`, Hive) — survives app kills and reboots.
- Only queues syncable methods (`POST/PUT/DELETE/PATCH`); excludes paths you list (`/auth/*` etc).
- Two operating modes via `OfflineSyncConfig.returnSyntheticResponse`:
  - `true` — returns a fake `200` with `{ '_offlineQueued': true, '_syncId': … }`; UI thinks it succeeded.
  - `false` — propagates a `DioException` so `ApiCallHandler.handleWrite` runs `optimisticCacheCall` and returns `OfflineQueuedFailure(syncId)` to the UI.
- **Max body size guard** (default 5 MB) skips queuing huge uploads.
- **Strong typing of sync state** via `SyncEvent`: `SyncStarted`, `SyncItemSucceeded`, `SyncItemFailed`, `SyncItemDiscarded`, `SyncCompleted`, `SyncIdle(pendingCount)` — perfect for badges and snackbars.
- `SyncServiceManager` watches `NetworkInfo.onConnectivityChanged` and auto-drains the queue with `processingDelay` between items.
- Per-item `maxRetries` (default 5) before discard.
- Uses a **separate `Dio`** to replay (with `replayMarker`) so replays don't re-enqueue themselves.

**Weakness**
- `FormData` (file uploads) cannot be queued — Hive can't serialize binary payloads cleanly.
- Replays don't carry the original `CancelToken` or progress callbacks.
- The `syncId` is only useful if your UI tracks it — extra plumbing for showing a per-item "queued/syncing" badge.
- Order is FIFO by `createdAt` — if two requests must run in order (e.g., create then update the same resource), you have to design the queue payload accordingly.
- Excluded-paths matching is `String.contains` — be careful with very short path fragments.

**How to use**

```dart
// In NetworkHelper.createDio() — pass syncQueue=null to disable.
OfflineSyncInterceptor(
  queue: syncQueue,
  config: OfflineSyncConfig(
    returnSyntheticResponse: false,   // propagate error → ApiCallHandler maps it
    maxRetries: 5,
    excludedPaths: [
      ApiConstant.login,
      ApiConstant.verifyOtp,
      ApiConstant.logout,
      ApiConstant.refreshToken,
    ],
  ),
);

// Listen to events for UI
getIt<SyncServiceManager>().eventStream.listen((event) {
  switch (event) {
    case SyncStarted(:final totalCount):    showSnack('Syncing $totalCount items…');
    case SyncCompleted(:final successCount, :final failedCount):
      showSnack('Synced $successCount, failed $failedCount');
    case SyncIdle(:final pendingCount):     pendingBadge.value = pendingCount;
    case SyncItemSucceeded():               /* optionally refresh UI */
    case SyncItemFailed(:final error):      log(error);
    case SyncItemDiscarded(:final request): log('Gave up on ${request.path}');
  }
});

// Pending count badge (alt. to events)
StreamBuilder<int>(
  stream: getIt<SyncServiceManager>().pendingCountStream,
  builder: (ctx, snap) => Badge(label: Text('${snap.data ?? 0}')),
);
```

---

### 8. NetworkInfo

[network_info.dart](network_info.dart) — thin wrapper around `connectivity_plus`.

**When to use**
- Pre-flight check before an expensive request.
- React to connectivity changes (banner "You're offline").
- `ApiCallHandler.handleRead` uses it under the hood when you pass it.

**Power**
- `isConnected` — one-shot check (returns `true` if *any* transport is up).
- `onConnectivityChanged` — broadcast `Stream<bool>`.

**Weakness**
- "Connectivity = on" doesn't guarantee "internet works" — Wi-Fi captive portals will report online but block traffic. For a *true* reachability check, send a HEAD to a known endpoint.

**How to use**

```dart
if (await getIt<NetworkInfo>().isConnected) {
  await repo.refresh();
}

getIt<NetworkInfo>().onConnectivityChanged.listen((online) {
  offlineBanner.value = !online;
});
```

---

### 9. AuthTokenStore

[local_storage/auth_token_store.dart](local_storage/auth_token_store.dart).

**When to use**
- After login: save the token. On every request: `AuthInterceptor` reads it. On logout: clear it.

**Power**
- **Hybrid storage**: volatile (in-memory) + persistent (`SecureStorage`, OS keychain). Reads from memory first to avoid keychain latency on hot paths.
- **`persist: bool` toggle** — controls "Remember me" semantics. Non-persistent sessions stay in memory only and die with the process.
- `hasSession()` / `isPersistentSession()` for splash / boot flows.

**Weakness**
- Volatile token isn't preserved across isolates.
- Depends on app-level `SecureStorage` + `SharedPreferences` wrappers ([core/local_storage/secure_storage.dart](../../local_storage/secure_storage.dart) in your app) — wire those before this.

**How to use**

```dart
final store = getIt<AuthTokenStore>();

// Login (Remember me ON)
await store.saveToken(newToken, persist: true);

// Login (Remember me OFF)
await store.saveToken(newToken, persist: false);

// Splash screen: should we route to home or login?
final loggedIn = await store.hasSession();

// Logout
await store.clearToken();
```

---

### 10. LocalStorageApiService (Hive)

[local_storage/local_storage_api_service.dart](local_storage/local_storage_api_service.dart) — abstract; [hive_local_storage_api_service.dart](local_storage/hive_local_storage_api_service.dart) — Hive impl.

**When to use**
- When you want to cache **parsed models** (not raw HTTP responses).
- As `cacheCall` / `getCachedData` for `ApiCallHandler.handleRead`.
- For optimistic write caches via `handleWrite.optimisticCacheCall`.

**Power**
- Simple key/value JSON-map interface — no Hive type adapters / `@HiveType`.
- `_normalizeMap` recursively turns `Map<dynamic, dynamic>` (Hive's native shape) into `Map<String, dynamic>` — safe to feed straight into `fromJson`.

**Weakness**
- Stores `Map<String, dynamic>` only — you serialize manually with `toJson`/`fromJson`.
- `clearAll()` calls `Hive.deleteFromDisk()` which nukes **all** Hive boxes, not just this one. Use cautiously (or refactor to `box.clear()`).
- No TTL — you manage staleness yourself.

**How to use**

```dart
// Register a box per domain
final box = await Hive.openBox('user_box');
getIt.registerLazySingleton<LocalStorageApiService>(
  () => HiveLocalStorageApiService(box),
);

// Cache a profile
await storage.save(key: 'profile', data: profile.toJson());

// Read it
final json = storage.read('profile');
final cached = json == null ? null : UserProfile.fromJson(json);
```

---

### 11. FileData & uploads/downloads

[file_data.dart](file_data.dart) — cross-platform file abstraction.

**When to use**
- Any multipart upload that has to work on mobile **and** Flutter Web.
- When file source may be: a filesystem path, raw `Uint8List`, or a `blob:` URL (Web image picker).

**Power**
- Factories cover every case:
  - `FileData.fromPath('/sdcard/img.jpg')` — mobile
  - `FileData.fromBytes(bytes, filename: 'img.jpg')` — web / in-memory
  - `FileData.fromBlobUrl('blob:…', filename: 'img.jpg')` — web pickers
  - `FileData.fromImagePath(path, filename: 'img.jpg')` — auto-routes blob/file
- `ApiService.multipartRequest` walks the data map **recursively** — nested `FileData` inside `data` is found and converted to `MultipartFile`.
- Combined with `recreateFormData` stash, **FormData uploads can be retried** by `RetryInterceptor`.

**Weakness**
- One-of-three constructor invariants enforced only by `assert` (debug-only).
- Blob URL resolution must be done by the upload path — not handled here.

**How to use**

Upload:

```dart
await api.multipartRequest<Map<String, dynamic>>(
  '/user/signatures',
  MethodType.post,
  files: {
    'signature_file': FileData.fromImagePath(
      signatureFilePath,
      filename: signatureFilePath.split('/').last,
      contentType: ('image', 'png'),
    ),
  },
  data: {'name': name, 'signature_type': signatureType},
  onSendProgress: (sent, total) =>
      print('Uploaded ${(sent / total * 100).toInt()}%'),
);
```

Download:

```dart
await api.download(
  'https://example.com/doc.pdf',
  '/path/to/save/doc.pdf',
  onReceiveProgress: (got, total) {
    if (total != -1) print('${(got / total * 100).toInt()}%');
  },
);
```

---

### 12. Error handling: AppException / AppFailure / ApiFailureHandler

[error/app_exception.dart](error/app_exception.dart), [error/app_failure.dart](error/app_failure.dart), [error/api_failure_helper.dart](error/api_failure_helper.dart).

**When to use**
- Convert any error (`DioException`, `SocketException`, `TimeoutException`, `FormatException`, parse errors) into a typed `AppFailure` the UI can branch on.
- Already used internally by `ApiCallHandler` — most repository code just uses `Result.failure`.

**Power**
- **Two layers, on purpose**:
  - `AppException` (sealed) — what was thrown.
  - `AppFailure` (sealed) — what the UI sees (no stack traces, no Dio types leaking into presentation).
  - Conversion via `AppException.toFailure()` extension.
- `ApiFailureHandler.handle(error)` is the **one entry point**:
  - Maps Dio types → status codes → typed exceptions.
  - Extracts server messages from common JSON shapes (`message`, `error`, `error.message`, `errors.<field>[0]`).
  - Logs the original *and* mapped error via `AppLog`.
  - Falls back to localized strings from `S.current.*` (the project's `intl` generated class).
- Built-in failures: `NetworkFailure`, `ServerFailure`, `CacheFailure`, `NoCachedDataFailure`, `OfflineQueuedFailure(syncId)`, `UnknownFailure`, `DuplicateRequestFailure`.

**Weakness**
- Depends on the generated `S` class — if you change locales infrastructure, update this.
- `_extractMessage` makes assumptions about server JSON shape; tweak for a different backend.
- `403 → UnauthorizedException` collapse means you can't distinguish "no token" vs "no permission" at the failure layer — branch on `code` if needed.

**How to use**

If you bypass `ApiCallHandler` and call Dio directly:

```dart
try {
  final res = await api.get('/heavy');
  return Right(parse(res.data));
} catch (e) {
  return Left(ApiFailureHandler.handle(e));
}
```

UI / Bloc:

```dart
state.result.failure!.when(
  network: () => offlineBanner(),
  server: (msg) => snack(msg),
  offlineQueued: (id) => snack('Queued. Will sync.'),
  duplicate: () => /* ignore — handled upstream */,
  other: (msg) => snack(msg),
);
```

---

## End-to-end recipes

### A. Read endpoint with cache + offline fallback

```dart
class HomeRepository {
  final ApiService api;
  final LocalStorageApiService storage;
  final NetworkInfo networkInfo;
  HomeRepository(this.api, this.storage, this.networkInfo);

  Future<Result<HomeData>> getHome() {
    return ApiCallHandler.handleRead<HomeData>(
      networkInfo: networkInfo,
      remoteCall: () async {
        final res = await api.get(ApiConstant.home);
        return HomeData.fromJson(res.data);
      },
      cacheCall: (data) => storage.save(key: 'home', data: data.toJson()),
      getCachedData: () async {
        final json = storage.read('home');
        return json == null ? null : HomeData.fromJson(json);
      },
    );
  }
}
```

### B. Write endpoint with offline queue + optimistic update

```dart
class TripRepository {
  final ApiService api;
  final LocalStorageApiService storage;
  TripRepository(this.api, this.storage);

  Future<Result<Trip>> createTrip(Trip trip) {
    return ApiCallHandler.handleWrite<Trip>(
      remoteCall: () async {
        final res = await api.post(ApiConstant.trips, data: trip.toJson());
        return Trip.fromJson(res.data);
      },
      cacheCall: (saved) => storage.save(
        key: 'trip-${saved.id}',
        data: saved.toJson(),
      ),
      optimisticCacheCall: () => storage.save(
        key: 'trip-pending-${trip.localId}',
        data: trip.toJson(),
      ),
    );
  }
}

// Bloc
final result = await tripRepo.createTrip(trip);
if (result.isSuccess) emit(Created(result.value!));
else if (result.failure is OfflineQueuedFailure) {
  final syncId = (result.failure as OfflineQueuedFailure).syncId;
  emit(Queued(syncId));
} else if (result.failure is DuplicateRequestFailure) {
  // ignore — user double-tapped
} else {
  emit(Error(result.failure!.message));
}
```

### C. File upload with retry on flaky network

```dart
await api.multipartRequest<Map<String, dynamic>>(
  '/uploads',
  MethodType.post,
  files: {
    'avatar': FileData.fromBytes(
      bytes,
      filename: 'avatar.png',
      contentType: ('image', 'png'),
    ),
  },
  data: {'caption': caption},
  retryOptions: RetryOptions(
    maxRetries: 3,
    retryDelay: const Duration(seconds: 2),
  ),
  onSendProgress: (sent, total) =>
      uploadProgress.value = sent / total,
);
```

### D. Per-request cache override (fresh-only)

```dart
final res = await api.get(
  ApiConstant.notifications,
  cacheOptions: CacheService.instance.buildOptions(
    policy: CachePolicy.request,           // network always, cache only on failure
    maxStale: const Duration(minutes: 5),
  ),
);
```

### E. Logout cleanup

```dart
Future<void> logout() async {
  try {
    await api.post(ApiConstant.logout);
  } catch (_) {/* don't block logout on network */}

  await getIt<AuthTokenStore>().clearToken();
  await CacheService.instance.clearAll();
  await getIt<SyncQueue>().clear();
  await getIt<LocalStorageApiService>().clearAll();
}
```

---

## Quick decision matrix

| You need to… | Use |
|---|---|
| Make any HTTP call | `ApiService` |
| Get a typed `Result<T>` instead of try/catch | `ApiCallHandler.handleRead / handleWrite` |
| Attach a bearer token / refresh on 401 | `AuthInterceptor` (auto) |
| Retry on 5xx/429/timeout with backoff | `RetryInterceptor` (auto, override with `RetryOptions`) |
| Cache HTTP responses on disk | `DioCacheInterceptor` + `CacheService` |
| Cache parsed models | `LocalStorageApiService` |
| Prevent double-tap duplicates | `DuplicateRequestInterceptor` (auto) |
| Queue writes when offline, replay later | `OfflineSyncInterceptor` + `SyncServiceManager` |
| Check or subscribe to connectivity | `NetworkInfo` |
| Upload files on mobile + web | `FileData` + `ApiService.multipartRequest` |
| Show user-friendly errors | `AppFailure` (via `ApiFailureHandler.handle`) |
| Save/load auth tokens | `AuthTokenStore` |
