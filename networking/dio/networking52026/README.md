# Networking Helper — May 2026 revision

> **Status:** experimental. This folder is a snapshot of [../networking/](../networking/) plus the P0→P2 improvements from the May 2026 review. **Test thoroughly before promoting** to your main networking dir. Once validated, copy back over `core/networking/` and delete this folder. See [the promotion checklist](#promotion-checklist).

A complete, production-ready networking stack for Flutter built on top of [Dio](https://pub.dev/packages/dio). Bundles authentication, retry with backoff, HTTP caching, offline write-queueing with auto-sync, **idempotency keys**, duplicate-request protection, unified error handling, **production telemetry**, **captive-portal-proof reachability**, file upload/download (incl. **offline uploads**), and a typed `Result`/`Either` wrapper for callers.

---

## Folder map

```
networking52026/
├── api_call_handler.dart            handleRead / handleWrite + Result<T>
├── api_constant.dart                Base URL + endpoint paths
├── api_service.dart                 Abstract API contract
├── api_service_impl.dart            Dio-backed implementation (ApiServiceImpl)
├── auth_interceptor.dart            Token attach + 401 refresh + logout hook
├── cache_service.dart               Singleton cache store + options
├── duplicate_request_interceptor.dart  Drops duplicate in-flight requests
├── endpoint_cache_registry.dart     Per-path cache policy registry
├── file_data.dart                   Cross-platform file abstraction
├── idempotency_interceptor.dart     Idempotency-Key header injector
├── method_type.dart                 HTTP method enum
├── network_helper.dart              Dio factory (wires interceptors)
├── network_info.dart                Connectivity check + reachability probe
├── networking.dart                  Barrel file (one import)
├── telemetry_interceptor.dart       Request observability emitter
│
├── error/
│   ├── api_failure_handler.dart     Maps any error → AppFailure
│   ├── app_exception.dart           Sealed exceptions
│   ├── app_failure.dart             Sealed failures (UI-facing)
│   ├── error.dart                   Barrel
│   └── server_message_extractor.dart  Pluggable strategy
│
├── local_storage/
│   ├── auth_token_store.dart        Volatile + secure token store
│   ├── hive_local_storage_api_service.dart
│   ├── local_storage.dart
│   └── local_storage_api_service.dart
│
├── offline_sync/
│   ├── offline_sync.dart            Barrel
│   ├── offline_sync_config.dart     Queue policy/config
│   ├── offline_sync_interceptor.dart  Queues failed writes when offline
│   ├── queued_request.dart          Hive-serializable request (+ filePaths + idempotencyKey)
│   ├── sync_event.dart              UI events (started/failed/idle…)
│   ├── sync_queue.dart              Persistent FIFO queue
│   └── sync_service_manager.dart    Connectivity-aware replayer
│
└── retry/
    ├── retry.dart                   Barrel
    ├── retry_interceptor.dart       Exponential backoff + jitter
    └── retry_options.dart           Per-request overrides
```

Import everything with one line:

```dart
import 'package:<your_app>/core/networking/networking.dart';
```

---

## Table of contents

1. [Features at a glance](#features-at-a-glance)
2. [Setup & dependency injection](#setup--dependency-injection)
3. [How to wire `onForceLogout` with AuthBloc](#how-to-wire-onforcelogout-with-authbloc)
4. [Feature reference](#feature-reference)
   - [1. ApiService (HTTP client facade)](#1-apiservice-http-client-facade)
   - [2. ApiCallHandler & Result&lt;T&gt;](#2-apicallhandler--resultt)
   - [3. AuthInterceptor (token + refresh + logout hook)](#3-authinterceptor-token--refresh--logout-hook)
   - [4. RetryInterceptor (backoff + jitter)](#4-retryinterceptor-backoff--jitter)
   - [5. CacheService + DioCacheInterceptor](#5-cacheservice--diocacheinterceptor)
   - [6. EndpointCacheRegistry (per-path policy)](#6-endpointcacheregistry-per-path-policy)
   - [7. DuplicateRequestInterceptor](#7-duplicaterequestinterceptor)
   - [8. IdempotencyInterceptor](#8-idempotencyinterceptor)
   - [9. TelemetryInterceptor](#9-telemetryinterceptor)
   - [10. OfflineSync (+ offline uploads)](#10-offlinesync--offline-uploads)
   - [11. NetworkInfo (+ reachability ping)](#11-networkinfo--reachability-ping)
   - [12. AuthTokenStore](#12-authtokenstore)
   - [13. LocalStorageApiService (Hive)](#13-localstorageapiservice-hive)
   - [14. FileData & uploads/downloads](#14-filedata--uploadsdownloads)
   - [15. Error layer (+ pluggable extractor)](#15-error-layer--pluggable-extractor)
5. [End-to-end recipes](#end-to-end-recipes)
6. [What changed vs `networking/`](#what-changed-vs-networking)
7. [Promotion checklist](#promotion-checklist)

---

## Features at a glance

| # | Feature | When to use |
|---|---------|-------------|
| 1 | **ApiService** | Every HTTP call (GET/POST/PUT/PATCH/DELETE/HEAD, download, multipart) |
| 2 | **ApiCallHandler / Result** | Repository layer — converts thrown errors into typed `Either<AppFailure, T>` |
| 3 | **AuthInterceptor** | Bearer auth, 401-refresh, forced-logout hook |
| 4 | **RetryInterceptor** | Flaky networks, 5xx, 429, timeouts — auto retry with exponential backoff |
| 5 | **CacheService / DioCacheInterceptor** | Cache HTTP responses on disk for offline / faster repeats |
| 6 | **EndpointCacheRegistry** | Centralize cache policy by path-regex instead of per-call overrides |
| 7 | **DuplicateRequestInterceptor** | Stops double-tap submissions hitting the server twice |
| 8 | **IdempotencyInterceptor** | Server-side dedupe via `Idempotency-Key` header (survives retries + replays) |
| 9 | **TelemetryInterceptor** | Production observability (works in release, unlike `PrettyDioLogger`) |
| 10 | **OfflineSync** | Persist write requests (incl. mobile multipart uploads) when offline and replay them when back online |
| 11 | **NetworkInfo** | Connectivity check + captive-portal-proof reachability probe |
| 12 | **AuthTokenStore** | Save/load the auth token (volatile + secure, persistent vs session) |
| 13 | **LocalStorageApiService** | Hive wrapper to cache structured JSON responses |
| 14 | **FileData** | Upload / multipart with one model across mobile (paths) and web (bytes) |
| 15 | **AppException / AppFailure** | Show user-friendly errors, branch UI on failure types |

---

## Setup & dependency injection

Recommended wiring with GetIt + Bloc:

```dart
// service_locator.dart
final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── Storage primitives ────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<SecureStorage>(SecureStorageImpl());

  // ── Hive boxes ─────────────────────────────────────────────────
  await Hive.initFlutter();
  await CacheService.instance.init();

  final syncQueue = SyncQueue();
  await syncQueue.init();
  getIt.registerSingleton<SyncQueue>(syncQueue);

  final userBox = await Hive.openBox('user_box');
  getIt.registerSingleton<LocalStorageApiService>(
    HiveLocalStorageApiService(userBox),
  );

  // ── Network stack (registered BEFORE feature blocs).
  //    The onForceLogout callback uses `getIt<AuthBloc>()` LAZILY —
  //    the lookup only fires when a 401 actually occurs at runtime,
  //    by which point AuthBloc has been registered below. So order
  //    doesn't matter as long as both are registered before runApp.
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
  getIt.registerLazySingleton<AuthTokenStore>(
    () => AuthTokenStoreImpl(
      secureStorage: getIt(),
      sharedPreferences: getIt(),
    ),
  );

  // Configure the pluggable error extractor for your backend
  ApiFailureHandler.messageExtractor = const DefaultServerMessageExtractor();

  // Build Dio (main + replay) via NetworkHelper
  getIt.registerSingletonAsync<NetworkHelper>(() async {
    return NetworkHelper(
      getIt<AuthTokenStore>(),
      getIt<SharedPreferences>(),
      syncQueue: syncQueue,

      // Forced-logout hook — fires once when refresh token fails.
      // `getIt<AuthBloc>()` resolves lazily inside the closure, so
      // it's fine that AuthBloc isn't registered yet at this point.
      onForceLogout: () {
        if (!getIt.isRegistered<AuthBloc>()) return;
        final bloc = getIt<AuthBloc>();
        if (bloc.isClosed) return;
        bloc.add(const LogoutEvent());
      },

      // Telemetry — sink to your analytics / crash reporter
      onTelemetry: (event) {
        AppLog.i('net', event.toString());
        FirebaseAnalytics.instance.logEvent(
          name: 'http_request',
          parameters: {
            'method': event.method,
            'path': event.path,
            'status': event.statusCode,
            'duration_ms': event.duration.inMilliseconds,
            'retries': event.retryCount,
            'ok': event.ok ? 1 : 0,
          },
        );
      },
    );
  });

  getIt.registerSingletonAsync<Dio>(
    () async => (await getIt.getAsync<NetworkHelper>()).createDio(),
    dependsOn: [NetworkHelper],
  );

  getIt.registerSingletonWithDependencies<ApiService>(
    () => ApiServiceImpl(getIt<Dio>()),
    dependsOn: [Dio],
  );

  // Replay Dio for offline-sync (Auth + Retry only)
  getIt.registerSingletonAsync<SyncServiceManager>(
    () async {
      final replayDio =
          await (await getIt.getAsync<NetworkHelper>()).createReplayDio();
      return SyncServiceManager(
        dio: replayDio,
        queue: getIt<SyncQueue>(),
        networkInfo: getIt<NetworkInfo>(),
      );
    },
    dependsOn: [NetworkHelper],
  );

  // ── Feature blocs / use cases / repositories — registered AFTER
  //    the network stack. AuthBloc lands here, alongside the rest.
  _registerFeatureAuth();
  // _registerFeatureXxx(); …

  await getIt.allReady();
  getIt<SyncServiceManager>().init();
}
```

In `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const MyApp());
}
```

> **Why this order is safe.** `onForceLogout` is a closure — it captures the *symbol* `getIt<AuthBloc>` but doesn't invoke it. The actual lookup only happens when a 401 fires at runtime, long after `_registerFeatureAuth()` has registered the bloc. Both halves just have to be registered before `runApp()` — which they are.

> **Interceptor order matters.** [network_helper.dart](network_helper.dart) wires them in this order:
> `Telemetry → Idempotency → DuplicateRequest → Auth → Cache → Retry → OfflineSync → Logger`.
> Telemetry runs first so it observes everything (including retries). Idempotency runs before Duplicate so the key is set on the very first attempt. OfflineSync runs last so it only queues if cache also missed and all retries failed.

---

## How to wire `onForceLogout` with AuthBloc

`AuthInterceptor` fires `_triggerLogout()` exactly once when token refresh fails. Wire the callback at `NetworkHelper` construction — anything callable works.

### With Bloc (recommended)

```dart
NetworkHelper(
  tokenStore,
  prefs,
  syncQueue: syncQueue,
  onForceLogout: () => getIt<AuthBloc>().add(const LogoutEvent()),
).createDio();
```

The `AuthBloc.LogoutEvent` handler then:

```dart
// auth_bloc.dart
on<LogoutEvent>((event, emit) async {
  emit(AuthLoggingOut());
  await getIt<AuthTokenStore>().clearToken();
  await CacheService.instance.clearAll();
  await getIt<SyncQueue>().clear();      // optional: cancel offline writes
  await getIt<LocalStorageApiService>().clearAll();
  emit(AuthLoggedOut());
  // GoRouter / Navigator listens to AuthLoggedOut and routes to /login
});
```

### Without Bloc

```dart
final navigatorKey = GlobalKey<NavigatorState>();

NetworkHelper(
  tokenStore,
  prefs,
  onForceLogout: () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login', (_) => false,
    );
  },
).createDio();
```

### Race-condition gotcha

`onForceLogout` fires from a Dio interceptor, often during a network call that's already in flight. Guard against disposed blocs:

```dart
onForceLogout: () {
  if (!getIt.isRegistered<AuthBloc>()) return;
  final bloc = getIt<AuthBloc>();
  if (bloc.isClosed) return;
  bloc.add(const LogoutEvent());
},
```

---

## Feature reference

### 1. ApiService (HTTP client facade)

[api_service.dart](api_service.dart) defines the contract, [api_service_impl.dart](api_service_impl.dart) provides the Dio-backed implementation (`ApiServiceImpl`).

**When to use**
- Every HTTP call in the app. Repositories depend on `ApiService`, not on `Dio` directly.

**Power**
- One uniform API for `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `download`, and `multipartRequest`.
- Per-request `RetryOptions` and `CacheOptions` overrides — no need to touch the Dio instance.
- `multipartRequest` accepts a `Map<String, FileData>` so you can upload from a file path (mobile) or raw bytes (web) with the same call.
- Stashes `recreateFormData` closure in `options.extra` so `RetryInterceptor` can rebuild the body on retry (FormData is single-shot in Dio).
- **Stashes an `_offlineMultipartSpec`** so `OfflineSyncInterceptor` can persist mobile uploads across an app restart.

**Weakness**
- Returns raw `Response<T>` — you still need a JSON parser around it. Pair with `ApiCallHandler.handleRead/handleWrite` to get `Result<T>` instead.
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
- **NEW: `handleRead(verifyReachability: true)`** uses the captive-portal-proof probe instead of trusting the OS connectivity flag.
- `handleWrite`:
  - Silently drops `DuplicateRequestFailure` (so the bloc never emits a spurious error from a double-tap).
  - Detects offline errors, runs `optimisticCacheCall`, and returns `OfflineQueuedFailure(syncId)` so the UI can show "queued, will sync".
- Plugs straight into `Either<AppFailure, T>` (from `dartz`) for FP-style branching.

**Weakness**
- Requires `dartz`.
- `optimisticCacheCall` only fires when `OfflineSyncConfig.returnSyntheticResponse` is `false` — easy footgun if you flip that flag and forget.

**How to use**

```dart
// Read with cache fallback + captive-portal-proof check
Future<Result<UserProfile>> getProfile() {
  return ApiCallHandler.handleRead<UserProfile>(
    networkInfo: getIt<NetworkInfo>(),
    verifyReachability: true,            // optional, slower but accurate
    remoteCall: () async {
      final res = await api.get(ApiConstant.userProfile);
      return UserProfile.fromJson(res.data);
    },
    cacheCall: (profile) => _localDb.save(
      key: 'profile', data: profile.toJson(),
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
    cacheCall: (saved) =>
        _localDb.save(key: 'trip-${saved.id}', data: saved.toJson()),
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

### 3. AuthInterceptor (token + refresh + logout hook)

[auth_interceptor.dart](auth_interceptor.dart) — `QueuedInterceptor` that attaches the bearer token, refreshes on 401/403, and **calls your `onForceLogout` callback** when refresh fails.

**When to use**
- Any app with bearer-token auth and a refresh-token endpoint.

**Power**
- Auto-attaches `Authorization: Bearer …` on every request that isn't login/verify-OTP.
- Auto-attaches `Accept-Language` from `SharedPreferences`.
- **Single-flight refresh:** if 10 concurrent requests get 401, only one refresh call goes out; the rest await the same `Completer`.
- **Stale-token detection:** if another request already refreshed mid-flight, the failed request re-fetches with the new token instead of triggering a second refresh.
- **One-shot logout:** once refresh fails, `_forceLogout = true` short-circuits all subsequent 401s — no cascade of refresh+logout cycles.
- **NEW: `onForceLogout` callback** — wire your AuthBloc / Navigator / whatever at construction. See [the dedicated section](#how-to-wire-onforcelogout-with-authbloc).
- Resets state on login/register requests automatically.

**Weakness**
- Hardcoded refresh response shape (`data?['data']?['token']`) — adjust `_doRefreshToken` if your backend differs.
- Hardcoded "login"/"verify"/"logout" paths via `ApiConstant.*` — endpoints outside that list are assumed protected.
- No timeout on the refresh call itself; if `/auth/refresh` hangs, every 401 in flight is stuck on the `Completer`.

**How to use**

It's added by [network_helper.dart](network_helper.dart) automatically. Wire the logout callback once:

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
- POST is **not** retried on `receiveTimeout` — the request may have hit the server and you don't want a duplicate side effect. (Idempotency keys make this safer — see #8.)
- Exponential backoff (`baseDelay * 2^attempt`) with 50–100 % jitter, capped at `maxDelay` (default 30 s).
- Honors `Retry-After` header (both seconds and HTTP-date).
- Per-request override via `RetryOptions` parameter on `ApiService` methods.
- **Rebuilds `FormData` on retry** by calling the stashed `recreateFormData` closure.
- Preserves `extra` — so the **idempotency key set on attempt 1 is reused on every retry**.

**Weakness**
- Default `maxRetries=3` means a flaky link can stretch a request to ~14 s. Tune for your UX.
- Spinner stays on screen during retries — bad perception of latency.
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

### 5. CacheService + DioCacheInterceptor

[cache_service.dart](cache_service.dart) — singleton over `dio_cache_interceptor` + `http_cache_hive_store`.

**When to use**
- Read endpoints where stale data is acceptable for the offline / slow-network case.
- When you want **automatic** cache fallback on network failure (no extra repository code).

**Power**
- Default policy: `refreshForceCache` — always tries network first, falls back to cache on failure, with `maxStale: 7 days`.
- `hitCacheOnNetworkFailure: true` — failing fetch returns cached data instead of an error.
- Per-request `buildOptions(...)` for custom policies.
- Stored in the OS **temporary directory** — survives app restarts, cleared by the OS under pressure.
- Manual control: `clearAll()`, `clearForKey(key)`, `clearForPath(RegExp)`.

**Weakness**
- Caches `Response` — not parsed models. The model is rebuilt on every read.
- For structured offline reads of *parsed* models, prefer [LocalStorageApiService](#13-localstorageapiservice-hive) + `handleRead.getCachedData`.

**How to use**

```dart
// Default (already wired)
await api.get('/home');

// Per-request override
await api.get(
  '/news/feed',
  cacheOptions: CacheService.instance.buildOptions(
    policy: CachePolicy.request,
    maxStale: const Duration(hours: 1),
  ),
);

// Clear after logout
await CacheService.instance.clearAll();
await CacheService.instance.clearForPath(RegExp(r'/user/.*'));
```

---

### 6. EndpointCacheRegistry (per-path policy)

[endpoint_cache_registry.dart](endpoint_cache_registry.dart) — centralize cache policy by path-regex.

**When to use**
- When you have more than 2-3 endpoints with custom cache policies and you're tired of passing `cacheOptions:` at every call site.

**Power**
- Single source of truth for "which endpoint caches how long". Easier to audit.
- Per-call `cacheOptions:` still wins — registry only fills the gap.
- First matching pattern wins — register more specific patterns first.

**Weakness**
- **Not auto-wired into `NetworkHelper.createDio()`.** You add it manually once you've decided on rules.
- Regex matching has cost on every request (negligible for <50 rules).

**How to use**

```dart
final registry = EndpointCacheRegistry(
  fallback: CacheService.instance.defaultOptions,
)
  ..register(
    RegExp(r'^/news/feed$'),
    CacheService.instance.buildOptions(
      policy: CachePolicy.request,
      maxStale: const Duration(minutes: 5),
    ),
  )
  ..register(
    RegExp(r'^/user/profile'),
    CacheService.instance.buildOptions(
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(hours: 1),
    ),
  )
  ..register(
    RegExp(r'^/admin/.*'),
    CacheService.instance.buildOptions(policy: CachePolicy.noCache),
  );

// Wire BEFORE DioCacheInterceptor:
dio.interceptors.add(EndpointCacheInterceptor(registry));
dio.interceptors.add(DioCacheInterceptor(options: registry.fallback));
```

---

### 7. DuplicateRequestInterceptor

[duplicate_request_interceptor.dart](duplicate_request_interceptor.dart).

**When to use**
- Always (it's wired by default). Stops accidental double-submits (rapid taps, navigation races) from hitting the server twice **in-process**.

**Power**
- Tracks in-flight requests by a canonical signature: `METHOD:URI:canonicalized-JSON-payload`.
- Map keys are sorted (via `SplayTreeMap`) so `{a:1, b:2}` and `{b:2, a:1}` collide.
- Only intercepts mutating methods — `GET/HEAD/OPTIONS` always pass through.
- Skips `FormData` (uploads aren't reliably hashable).
- Rejects duplicates with `DioExceptionType.cancel` and a sentinel message; `ApiCallHandler.handleWrite` recognizes it and returns `DuplicateRequestFailure`, which the bloc should silently ignore.

**Weakness**
- **In-memory only** — restarting the app clears the registry. Pair with [IdempotencyInterceptor](#8-idempotencyinterceptor) for server-side dedupe that survives restarts.
- File uploads (`FormData`) are not deduped here.
- Two requests differing only by a timestamp in the body are treated as different (correct, but be aware).

**How to use**

Zero-config:

```dart
// User taps submit 5x quickly:
for (var i = 0; i < 5; i++) {
  // Only the 1st goes out; the other 4 are silently dropped.
  await api.post('/orders', data: order.toJson());
}
```

---

### 8. IdempotencyInterceptor

[idempotency_interceptor.dart](idempotency_interceptor.dart) — adds `Idempotency-Key` to POST/PUT/PATCH/DELETE.

**When to use**
- Always, if your backend supports idempotency keys. Fixes the *entire* category of double-side-effect bugs:
  - Double-tap submits
  - Retry after request timeout (was the original processed? you'll never know)
  - Offline-queue replay (server may have received both the original AND the replay)

**Power**
- Auto-generates a UUID v4 on first request, stashes in `options.extra['idempotencyKey']`, sends as `Idempotency-Key` header.
- **Reuses the same key on retry** (`RetryInterceptor` preserves `extra`) — so server sees identical key on both attempts.
- **Reuses the same key on offline replay** — `QueuedRequest.idempotencyKey` is persisted, `SyncServiceManager` restores it.
- Explicit-key path: pass your own key when the operation has a natural ID (`'trip-${trip.localId}'`).
- GET/HEAD/OPTIONS skipped (already idempotent).

**Weakness**
- **Useless without backend support.** Server must keep a `key → response` cache for ~24h and return the cached response on collision.
- A buggy backend that doesn't honor the header gives you no protection.

**How to use**

**Auto path (recommended).** Just call `handleWrite`:

```dart
await ApiCallHandler.handleWrite<Trip>(
  remoteCall: () async {
    final res = await api.post('/trips', data: trip.toJson());
    return Trip.fromJson(res.data);
  },
);
// → Idempotency-Key: 8b94f7c2-… is auto-injected
```

**Server contract:**

| Request | Header | Server behavior |
|---|---|---|
| First call | `Idempotency-Key: abc-123` | Process. Cache response under `abc-123` for ~24h. |
| Retry / replay | `Idempotency-Key: abc-123` | Return cached response, do NOT re-process. |

**Explicit path:**

```dart
await api.post(
  '/trips',
  data: trip.toJson(),
  options: Options(extra: {
    IdempotencyInterceptor.extraKey: 'trip-${trip.localId}',
  }),
);
```

---

### 9. TelemetryInterceptor

[telemetry_interceptor.dart](telemetry_interceptor.dart) — emits `TelemetryEvent` on every completed request.

**When to use**
- Always, in production. `PrettyDioLogger` only runs in debug mode — without this, you're flying blind in release.

**Power**
- Captures: method, path, status code, ok flag, duration, retry count, replay flag, error type, query params.
- Fires on success AND failure.
- Stamps `_telemetry_start` first thing, so duration includes all interceptor work below it.
- Wrapped in try-catch — telemetry failures never break the request pipeline.

**Weakness**
- You pay the cost of building the event on every request (~microseconds, but real).
- `event.queryParameters` may contain PII — strip before logging to analytics.
- Doesn't capture response body size (would require a copy / parse cost).

**How to use**

```dart
NetworkHelper(
  tokenStore,
  prefs,
  onTelemetry: (event) {
    AppLog.i('net', event.toString());

    unawaited(FirebaseAnalytics.instance.logEvent(
      name: 'http_request',
      parameters: {
        'method': event.method,
        'path': event.path,
        'status': event.statusCode,
        'duration_ms': event.duration.inMilliseconds,
        'retries': event.retryCount,
        'ok': event.ok ? 1 : 0,
        if (event.wasReplay) 'replay': 1,
      },
    ));

    if (!event.ok && event.statusCode >= 500) {
      Sentry.captureMessage(
        'Server error: ${event.method} ${event.path} -> ${event.statusCode}',
      );
    }
  },
).createDio();
```

`TelemetryEvent` shape:

```dart
class TelemetryEvent {
  final String method;             // GET, POST, …
  final String path;
  final int statusCode;            // 0 if no response (network error)
  final bool ok;                   // 2xx
  final Duration duration;
  final int retryCount;
  final bool wasReplay;
  final DioExceptionType? errorType;
  final Map<String, dynamic>? queryParameters;
}
```

---

### 10. OfflineSync (+ offline uploads)

[offline_sync/](offline_sync/) — interceptor + queue + manager + events.

**When to use**
- Apps that must accept **writes** while offline (chat send, form submit, status update) and replay them when connectivity returns.

**Power**
- **Persistent queue** (Hive) — survives app kills and reboots.
- Only queues syncable methods (`POST/PUT/DELETE/PATCH`); excludes paths you list (`/auth/*` etc).
- Two operating modes via `OfflineSyncConfig.returnSyntheticResponse`:
  - `true` — returns a fake `200` with `{ '_offlineQueued': true, '_syncId': … }`.
  - `false` — propagates a `DioException` so `ApiCallHandler.handleWrite` returns `OfflineQueuedFailure(syncId)` to the UI.
- **Max body size guard** (default 5 MB) skips queuing huge uploads.
- Strong typing of sync state via `SyncEvent`: `SyncStarted`, `SyncItemSucceeded`, `SyncItemFailed`, `SyncItemDiscarded`, `SyncCompleted`, `SyncIdle(pendingCount)`.
- `SyncServiceManager` watches connectivity and auto-drains with `processingDelay` between items.
- Per-item `maxRetries` (default 5) before discard.
- Uses a **dedicated replay Dio** (via `NetworkHelper.createReplayDio`) — Auth+Retry only, no duplicate detection or cache. AuthInterceptor re-attaches a fresh token on every replay.
- **Authorization header is NEVER persisted in Hive** — stale tokens can't leak.
- **Idempotency key is persisted and reused** on replay — server dedupes if both the original and the replay reached it.
- **NEW: Mobile multipart uploads survive the queue.** `ApiServiceImpl.multipartRequest` stashes a serializable spec; `OfflineSyncInterceptor` records the local file paths; `SyncServiceManager._rebuildFormData` rebuilds the upload on replay.

**Weakness**
- **Web bytes uploads cannot be queued** — bytes can't survive an app restart inside Hive without writing them out separately (not done here). Mobile uploads (real filesystem paths) queue and replay fine.
- If the user deletes a source file before sync, that field is silently dropped from the replayed request.
- Order is FIFO by `createdAt` — if two requests must run in order (create then update the same resource), design the queue payload accordingly.
- Excluded-paths matching is `String.contains` — be careful with short fragments.

**How to use**

Wiring is automatic via `NetworkHelper`. To listen for sync events:

```dart
getIt<SyncServiceManager>().eventStream.listen((event) {
  switch (event) {
    case SyncStarted(:final totalCount):
      showSnack('Syncing $totalCount items…');
    case SyncCompleted(:final successCount, :final failedCount):
      showSnack('Synced $successCount, failed $failedCount');
    case SyncIdle(:final pendingCount):
      pendingBadge.value = pendingCount;
    case SyncItemSucceeded():
      /* optionally refresh UI */
    case SyncItemFailed(:final error):
      log(error);
    case SyncItemDiscarded(:final request):
      log('Gave up on ${request.path}');
  }
});

// Pending count badge
StreamBuilder<int>(
  stream: getIt<SyncServiceManager>().pendingCountStream,
  builder: (ctx, snap) => Badge(label: Text('${snap.data ?? 0}')),
);
```

**Offline upload example:**

```dart
// Works identically online and offline — multipartRequest stashes a spec
// that OfflineSyncInterceptor uses to persist the upload if needed.
await api.multipartRequest<Map<String, dynamic>>(
  '/user/signatures',
  MethodType.post,
  files: {
    'signature_file': FileData.fromPath(
      signatureFilePath,
      contentType: ('image', 'png'),
    ),
  },
  data: {'name': name},
);
```

---

### 11. NetworkInfo (+ reachability ping)

[network_info.dart](network_info.dart).

**When to use**
- Pre-flight check before an expensive request.
- React to connectivity changes (banner "You're offline").
- `ApiCallHandler.handleRead` uses it under the hood when you pass it.

**Power**
- `isConnected` — cheap, one-shot check via `connectivity_plus`.
- `onConnectivityChanged` — broadcast `Stream<bool>` of OS-level changes.
- **NEW: `hasInternetAccess`** — fires a real HEAD probe to a known host (default `https://1.1.1.1`) so captive portals can't lie. Configurable `pingUrl` and `pingTimeout`.
- Web-aware: `hasInternetAccess` skips the raw-socket probe and returns the connectivity result (browsers handle captive portals themselves).

**Weakness**
- The probe adds 50–200 ms per check. Use only on critical paths.
- Default ping host is external (`1.1.1.1`). If your app must run air-gapped, override `pingUrl` to an internal endpoint.

**How to use**

```dart
// Cheap check
if (await getIt<NetworkInfo>().isConnected) {
  await repo.refresh();
}

// Truthful check (captive-portal-proof)
if (await getIt<NetworkInfo>().hasInternetAccess) {
  await repo.refresh();
}

// Custom probe target
NetworkInfoImpl(
  pingUrl: Uri.parse('https://api.your-company.com/healthz'),
  pingTimeout: const Duration(seconds: 2),
);

// React to changes
getIt<NetworkInfo>().onConnectivityChanged.listen((online) {
  offlineBanner.value = !online;
});
```

---

### 12. AuthTokenStore

[local_storage/auth_token_store.dart](local_storage/auth_token_store.dart).

**When to use**
- After login: save the token. On every request: `AuthInterceptor` reads it. On logout: clear it.

**Power**
- **Hybrid storage**: volatile (in-memory) + persistent (`SecureStorage`, OS keychain). Reads from memory first to avoid keychain latency on hot paths.
- **`persist: bool` toggle** — controls "Remember me" semantics. Non-persistent sessions stay in memory only and die with the process.
- `hasSession()` / `isPersistentSession()` for splash / boot flows.

**Weakness**
- Volatile token isn't preserved across isolates.
- Depends on app-level `SecureStorage` + `SharedPreferences` wrappers — wire those before this.

**How to use**

```dart
final store = getIt<AuthTokenStore>();

// Login (Remember me ON)
await store.saveToken(newToken, persist: true);

// Login (Remember me OFF)
await store.saveToken(newToken, persist: false);

// Splash screen: route to home or login?
final loggedIn = await store.hasSession();

// Logout
await store.clearToken();
```

---

### 13. LocalStorageApiService (Hive)

[local_storage/local_storage_api_service.dart](local_storage/local_storage_api_service.dart) — abstract; [hive_local_storage_api_service.dart](local_storage/hive_local_storage_api_service.dart) — Hive impl.

**When to use**
- When you want to cache **parsed models** (not raw HTTP responses).
- As `cacheCall` / `getCachedData` for `ApiCallHandler.handleRead`.
- For optimistic write caches via `handleWrite.optimisticCacheCall`.

**Power**
- Simple key/value JSON-map interface — no Hive type adapters / `@HiveType`.
- `_normalizeMap` recursively converts `Map<dynamic, dynamic>` (Hive's native shape) into `Map<String, dynamic>` — safe for `fromJson`.
- **`clearAll()` now scopes to the box** (fixed in May 2026) — won't nuke unrelated Hive data.

**Weakness**
- Stores `Map<String, dynamic>` only — you serialize manually.
- No TTL — you manage staleness yourself.

**How to use**

```dart
final box = await Hive.openBox('user_box');
getIt.registerLazySingleton<LocalStorageApiService>(
  () => HiveLocalStorageApiService(box),
);

await storage.save(key: 'profile', data: profile.toJson());

final json = storage.read('profile');
final cached = json == null ? null : UserProfile.fromJson(json);
```

---

### 14. FileData & uploads/downloads

[file_data.dart](file_data.dart) — cross-platform file abstraction.

**When to use**
- Any multipart upload that has to work on **mobile** (filesystem paths) **and** **Flutter Web** (raw bytes).

**Power**
- Two factories, one per source. Exactly one must be provided:
  - `FileData.fromPath('/sdcard/img.jpg')` — mobile / desktop
  - `FileData.fromBytes(bytes, filename: 'img.jpg')` — web / in-memory
- `FileData.fromFileResult(...)` convenience routes path-vs-bytes for you based on `FileResult.isWeb`.
- Invariant is enforced with a **runtime `ArgumentError`** (not `assert`) — release builds catch misuse too.
- `ApiService.multipartRequest` walks the data map **recursively** — nested `FileData` inside `data` is found and converted.
- Combined with `recreateFormData` stash, FormData uploads can be **retried**.
- Combined with the multipart spec stash, mobile uploads can be **queued offline**.

**Weakness**
- Web uploads (bytes-only) are not queueable offline — they have no persistable handle.

**How to use**

**Mobile** (camera, image_picker, file_picker with `XFile.path`):

```dart
await api.multipartRequest<Map<String, dynamic>>(
  '/user/signatures',
  MethodType.post,
  files: {
    'signature_file': FileData.fromPath(
      signatureFilePath,
      contentType: ('image', 'png'),
    ),
  },
  data: {'name': name, 'signature_type': signatureType},
);
```

**Web** (read bytes from the picker first — every web picker can do this):

```dart
final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
final bytes  = await picked!.readAsBytes();

await api.multipartRequest<Map<String, dynamic>>(
  '/user/signatures',
  MethodType.post,
  files: {
    'signature_file': FileData.fromBytes(
      bytes,
      filename: picked.name,
      contentType: ('image', 'png'),
    ),
  },
  data: {'name': name, 'signature_type': signatureType},
);
```

**Cross-platform** (one code path using your picker's `XFile`):

```dart
Future<FileData> _toFileData(XFile xfile) async {
  if (kIsWeb) {
    return FileData.fromBytes(
      await xfile.readAsBytes(),
      filename: xfile.name,
    );
  }
  return FileData.fromPath(xfile.path, filename: xfile.name);
}

// usage:
await api.multipartRequest('/upload', MethodType.post, files: {
  'image': await _toFileData(picked),
});
```

#### Uploading multiple files (a `List<FileData>`)

`_processValue` walks lists recursively — so the value of a `files:` entry
can be a `List<FileData>`. Dio serializes it as repeated parts under the
same key, which matches what most backends (Laravel, Express + Multer,
DRF, …) expect for array fields.

```dart
final picked = await ImagePicker().pickMultiImage();   // List<XFile>

final fileDataList = await Future.wait(picked.map(_toFileData));
//   List<FileData>

await api.multipartRequest<Map<String, dynamic>>(
  '/posts',
  MethodType.post,
  files: {
    // Backend receives `photos[]=…&photos[]=…&photos[]=…`
    'photos[]': fileDataList,
  },
  data: {'caption': caption},
  onSendProgress: (sent, total) =>
      uploadProgress.value = sent / total,
);
```

If your backend expects indexed keys (`photos[0]`, `photos[1]`, …) instead
of a repeated-key array, flatten the list yourself:

```dart
final files = <String, FileData>{
  for (var i = 0; i < fileDataList.length; i++)
    'photos[$i]': fileDataList[i],
};

await api.multipartRequest('/posts', MethodType.post, files: files,
    data: {'caption': caption});
```

For **mixed fields** (one cover image + a list of attachments), just
combine them — the recursive walker handles nesting:

```dart
await api.multipartRequest('/posts', MethodType.post, files: {
  'cover': cover,                 // FileData
  'attachments[]': attachments,   // List<FileData>
});
```

#### Single download

```dart
await api.download(
  'https://example.com/doc.pdf',
  '/path/to/save/doc.pdf',
  onReceiveProgress: (got, total) {
    if (total != -1) print('${(got / total * 100).toInt()}%');
  },
);
```

#### Downloading multiple files

`ApiService.download` is one-file-at-a-time. For batch downloads, drive it
yourself — pick the strategy that fits your UX.

**Parallel** — fast, but spikes bandwidth and may starve other requests:

```dart
final downloads = [
  ('https://example.com/a.pdf', '/save/a.pdf'),
  ('https://example.com/b.pdf', '/save/b.pdf'),
  ('https://example.com/c.pdf', '/save/c.pdf'),
];

await Future.wait(
  downloads.map((d) => api.download(d.$1, d.$2)),
);
```

**Sequential** — slower, but predictable and easier to cancel/resume:

```dart
for (final d in downloads) {
  await api.download(d.$1, d.$2);
}
```

**Bounded parallelism** — best of both. Run *N* at a time so you never
exceed a sensible concurrency limit (e.g. 3):

```dart
Future<void> downloadBatch(
  List<(String url, String path)> items, {
  int concurrency = 3,
}) async {
  final queue = List.of(items);
  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final next = queue.removeAt(0);
      await api.download(next.$1, next.$2);
    }
  }
  await Future.wait(List.generate(concurrency, (_) => worker()));
}

await downloadBatch(downloads);
```

**Per-file progress + overall progress.** Each `download` call has its own
`onReceiveProgress`; aggregate manually if you want a single bar:

```dart
final receivedBytes = <int>[for (final _ in downloads) 0];
final totalBytes    = <int>[for (final _ in downloads) -1];

await Future.wait([
  for (var i = 0; i < downloads.length; i++)
    api.download(
      downloads[i].$1,
      downloads[i].$2,
      onReceiveProgress: (got, total) {
        receivedBytes[i] = got;
        totalBytes[i] = total;
        // Recompute overall progress whenever any file ticks.
        if (totalBytes.every((t) => t > 0)) {
          final pct = receivedBytes.reduce((a, b) => a + b) /
                      totalBytes.reduce((a, b) => a + b);
          overallProgress.value = pct;
        }
      },
    ),
]);
```

**Cancellation.** Share a `CancelToken` across the batch so one tap kills
all in-flight downloads:

```dart
final cancelToken = CancelToken();

try {
  await Future.wait(
    downloads.map((d) => api.download(d.$1, d.$2, cancelToken: cancelToken)),
  );
} on DioException catch (e) {
  if (CancelToken.isCancel(e)) {
    // User aborted — clean up partial files if needed.
  }
}

// elsewhere (cancel button):
cancelToken.cancel('User cancelled download');
```

---

### 15. Error layer (+ pluggable extractor)

[error/app_exception.dart](error/app_exception.dart), [error/app_failure.dart](error/app_failure.dart), [error/api_failure_handler.dart](error/api_failure_handler.dart), [error/server_message_extractor.dart](error/server_message_extractor.dart).

**When to use**
- Convert any error into a typed `AppFailure` the UI can branch on. Already used internally by `ApiCallHandler`.

**Power**
- **Two layers, on purpose**:
  - `AppException` (sealed) — what was thrown.
  - `AppFailure` (sealed) — what the UI sees (no stack traces, no Dio types leaking into presentation).
  - Conversion via `AppException.toFailure()` extension.
- `ApiFailureHandler.handle(error)` is the **one entry point**:
  - Maps Dio types → status codes → typed exceptions.
  - Pulls server messages via the pluggable [ServerMessageExtractor](#server-message-extractor).
  - Logs the original *and* mapped error via `AppLog`.
  - Falls back to localized strings from `S.current.*`.
- Built-in failures: `NetworkFailure`, `ServerFailure`, `CacheFailure`, `NoCachedDataFailure`, `OfflineQueuedFailure(syncId)`, `UnknownFailure`, `DuplicateRequestFailure`.
- **NEW: Default extractor joins all field errors with `\n`** — previously, only the first field error from `{errors: {email: ['x'], password: ['y']}}` was shown.

**Weakness**
- Depends on the generated `S` class for localized fallbacks.
- `403 → UnauthorizedException` collapse means you can't distinguish "no token" vs "no permission" at the failure layer.

#### Server message extractor

Default behavior handles `{message}`, `{error}`, `{error: {message}}`, and Laravel-style `{errors: {field: [...]}}`. To override:

```dart
class MyApiMessageExtractor extends ServerMessageExtractor {
  const MyApiMessageExtractor();

  @override
  String? extract(dynamic data) {
    if (data is! Map) return null;
    // e.g. backend returns { "result": { "msg": "…" } }
    final msg = data['result']?['msg'];
    return msg is String && msg.isNotEmpty ? msg : null;
  }
}

// At app boot:
ApiFailureHandler.messageExtractor = const MyApiMessageExtractor();
```

#### Direct use

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
final failure = state.result.failure!;
if (failure is NetworkFailure) showOfflineBanner();
else if (failure is OfflineQueuedFailure) showSnack('Queued. Will sync.');
else if (failure is DuplicateRequestFailure) {/* ignore */}
else showSnack(failure.message);
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
      verifyReachability: true,    // captive-portal-proof
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

### B. Write endpoint with idempotency + offline queue + optimistic update

```dart
Future<Result<Trip>> createTrip(Trip trip) {
  return ApiCallHandler.handleWrite<Trip>(
    remoteCall: () async {
      final res = await api.post(
        ApiConstant.trips,
        data: trip.toJson(),
        options: Options(extra: {
          // Optional: explicit key. Otherwise the interceptor auto-generates.
          IdempotencyInterceptor.extraKey: 'trip-${trip.localId}',
        }),
      );
      return Trip.fromJson(res.data);
    },
    cacheCall: (saved) =>
        storage.save(key: 'trip-${saved.id}', data: saved.toJson()),
    optimisticCacheCall: () => storage.save(
      key: 'trip-pending-${trip.localId}',
      data: trip.toJson(),
    ),
  );
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

### C. File upload with retry on flaky network (works offline)

```dart
await api.multipartRequest<Map<String, dynamic>>(
  '/uploads',
  MethodType.post,
  files: {
    'photo': FileData.fromPath(
      photoPath,
      contentType: ('image', 'jpeg'),
    ),
  },
  data: {'caption': caption},
  retryOptions: RetryOptions(
    maxRetries: 3,
    retryDelay: const Duration(seconds: 2),
  ),
  onSendProgress: (sent, total) => uploadProgress.value = sent / total,
);
// Offline? The upload is queued and SyncServiceManager replays it
// when connectivity returns — including the file payload.
```

### D. Per-request cache override (fresh-only)

```dart
final res = await api.get(
  ApiConstant.notifications,
  cacheOptions: CacheService.instance.buildOptions(
    policy: CachePolicy.request,
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

### F. Production observability wiring

```dart
NetworkHelper(
  tokenStore, prefs, syncQueue: queue,
  onForceLogout: () => getIt<AuthBloc>().add(const LogoutEvent()),
  onTelemetry: (event) {
    // Always log
    AppLog.i('net', event.toString());

    // Anomaly → Sentry
    if (!event.ok && event.statusCode >= 500) {
      Sentry.captureMessage('500: ${event.method} ${event.path}');
    }
    if (event.duration > const Duration(seconds: 5)) {
      Sentry.captureMessage('SLOW: ${event.method} ${event.path} '
                            '${event.duration.inMilliseconds}ms');
    }

    // Aggregate → Firebase
    unawaited(FirebaseAnalytics.instance.logEvent(
      name: 'http_request',
      parameters: {
        'method': event.method,
        'path': event.path,
        'status': event.statusCode,
        'duration_ms': event.duration.inMilliseconds,
        'retries': event.retryCount,
        'ok': event.ok ? 1 : 0,
      },
    ));
  },
).createDio();
```

---

## What changed vs `networking/`

| # | Change | Files touched | Priority |
|---|---|---|---|
| 1 | **`ApiService` impl renamed to `ApiServiceImpl`** so the abstract `ApiService` contract isn't shadowed by its own implementation | `api_service_impl.dart`, `networking.dart` | P0 |
| 2 | **Auth refresh on offline-sync replays** — `Authorization` is no longer persisted into Hive; `NetworkHelper.createReplayDio()` builds a dedicated Auth+Retry-only Dio for `SyncServiceManager` | `offline_sync_interceptor.dart`, `sync_service_manager.dart`, `network_helper.dart` | P0 |
| 3 | **Idempotency keys** — new `IdempotencyInterceptor` emits `Idempotency-Key` for POST/PUT/PATCH/DELETE; key survives retries AND offline-queue replays | `idempotency_interceptor.dart` (new), `queued_request.dart`, `sync_service_manager.dart`, `network_helper.dart` | P1 |
| 4 | **Telemetry** — new `TelemetryInterceptor` emits `TelemetryEvent(method, path, status, duration, retryCount, wasReplay, errorType)` on every completed request, including failures | `telemetry_interceptor.dart` (new), `network_helper.dart` | P1 |
| 5 | **File uploads in the offline queue** — `ApiServiceImpl.multipartRequest` stashes a serializable `_offlineMultipartSpec`; `OfflineSyncInterceptor` persists local file paths; `SyncServiceManager._rebuildFormData` reconstructs the upload on replay. Bytes-only (web) uploads are still skipped | `api_service_impl.dart`, `queued_request.dart`, `offline_sync_interceptor.dart`, `sync_service_manager.dart` | P1 |
| 6 | **Pluggable server-message extractor** — `ApiFailureHandler.messageExtractor` slot; default extractor now joins **all** field errors with `\n` instead of returning only the first | `error/server_message_extractor.dart` (new), `error/api_failure_handler.dart`, `error/error.dart` | P2 |
| 7 | **Reachability ping** — `NetworkInfo.hasInternetAccess` does a real HEAD probe (defaults to `1.1.1.1`); `ApiCallHandler.handleRead(verifyReachability: true)` uses it | `network_info.dart`, `api_call_handler.dart` | P2 |
| 8 | **Per-endpoint cache registry** — `EndpointCacheRegistry` + `EndpointCacheInterceptor`; centralizes cache policy by path-regex | `endpoint_cache_registry.dart` (new), `networking.dart` | P2 |
| Bonus | `LocalStorageApiService.clearAll()` now calls `box.clear()` instead of `Hive.deleteFromDisk()` (was nuking the offline-sync box too) | `local_storage/hive_local_storage_api_service.dart` | bugfix |
| Bonus | `AuthInterceptor` now takes an `onForceLogout` callback at construction — no source edits needed to wire a logout flow | `auth_interceptor.dart`, `network_helper.dart` | bugfix |

---

## Promotion checklist

Before deleting the old folder, verify in your real app:

- [ ] `Idempotency-Key` is honored by your backend (POST the same key twice — second call returns cached response, no duplicate row).
- [ ] Offline upload + kill app + reopen with connectivity → file actually arrives.
- [ ] `onForceLogout` fires on a forced 401 (revoke token server-side, then make a request).
- [ ] Telemetry events appear in Firebase / Sentry / your dashboard.
- [ ] `hasInternetAccess` returns `false` on a captive-portal Wi-Fi.
- [ ] No analyzer warnings about unused exports.
- [ ] All imports in your app refer to `core/networking/` — no leftover `core/networking52026/` paths.

Then:

```bash
rm -rf core/networking
mv core/networking52026 core/networking
# update any direct deep-imports (search for 'networking52026')
```

---

## Quick decision matrix

| You need to… | Use |
|---|---|
| Make any HTTP call | `ApiService` |
| Get a typed `Result<T>` instead of try/catch | `ApiCallHandler.handleRead / handleWrite` |
| Attach a bearer token / refresh on 401 | `AuthInterceptor` (auto) + `onForceLogout:` |
| Retry on 5xx/429/timeout with backoff | `RetryInterceptor` (auto, override with `RetryOptions`) |
| Cache HTTP responses on disk | `DioCacheInterceptor` + `CacheService` |
| Centralize cache policies by path | `EndpointCacheRegistry` |
| Cache parsed models | `LocalStorageApiService` |
| Prevent double-tap duplicates (in-process) | `DuplicateRequestInterceptor` (auto) |
| Prevent duplicate side-effects across retries + restarts | `IdempotencyInterceptor` (auto) |
| Observe requests in production | `TelemetryInterceptor` + `onTelemetry:` |
| Queue writes when offline, replay later | `OfflineSyncInterceptor` + `SyncServiceManager` |
| Queue file uploads offline (mobile) | `multipartRequest` (transparent — uses spec stash) |
| Check connectivity (cheap) | `NetworkInfo.isConnected` |
| Check real reachability (defeats captive portals) | `NetworkInfo.hasInternetAccess` |
| Upload files on mobile + web | `FileData` + `ApiService.multipartRequest` |
| Show user-friendly errors | `AppFailure` (via `ApiFailureHandler.handle`) |
| Customize server error parsing | `ApiFailureHandler.messageExtractor = …` |
| Save/load auth tokens | `AuthTokenStore` |
