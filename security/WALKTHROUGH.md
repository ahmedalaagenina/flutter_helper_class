# شرح الكود خطوة بخطوة

الملف ده لشرح **إزاي الموديول شغال من جوه** — الكود بيبدأ منين، وبيعدي على إيه،
وبياخد القرار إزاي. لو انت بس عايز تركّبه وتمشي، اقرا `README.md` بدل ده.

---

## 1. الفكرة الكبيرة: تلات طبقات

الموديول مقسوم لتلات طبقات، وكل واحدة ما بتعرفش عن اللي فوقها حاجة:

```
┌─────────────────────────────────────────────────────────┐
│  DeviceGate            ← ويدجت. بيقرر يرسم إيه          │
│  DeviceBlockedScreen                                    │
└────────────────────────┬────────────────────────────────┘
                         │  بيقرا verdict
┌────────────────────────▼────────────────────────────────┐
│  DeviceIntegrity       ← المحرك. بيجمع إشارات ويحسب     │
│  DeviceIntegrityConfig    نتيجة. ما بيعرفش عن UI حاجة   │
│  DeviceSignal                                           │
└────────────────────────┬────────────────────────────────┘
                         │  بيسأل
┌────────────────────────▼────────────────────────────────┐
│  DeviceProbe           ← المكان الوحيد اللي فيه          │
│  PlatformDeviceProbe      plugins و dart:io             │
└─────────────────────────────────────────────────────────┘
```

**ليه التقسيم ده؟** عشان الطبقة الوسطى (المنطق كله) تبقى قابلة للاختبار. لو
المحرك كان بينادي `DeviceInfoPlugin()` على طول، مكنتش تقدر تجرب "إيه اللي
هيحصل على جالاكسي S23؟" غير لما تمسك جالاكسي S23 بإيدك.

---

## 2. رحلة الكود من أول سطر

### الخطوة 0 — `main()` في التطبيق بتاعك

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DeviceIntegrity.configure(DeviceIntegrityConfig(/* السياسة بتاعتك */));
  await DeviceIntegrity.evaluate();

  runApp(const MyApp());
}
```

سطرين بس. الأول بيحقن السياسة، والتاني بيشغّل الفحص.

### الخطوة 1 — `configure()`

[device_integrity.dart:71](device_integrity.dart#L71)

```dart
static void configure(DeviceIntegrityConfig config) {
  _config = config;
  reset();          // بيمسح الكاش، عشان سياسة جديدة = حكم جديد
}
```

`DeviceIntegrity` كلاس **static** (`abstract final class` — مش بيتعمله instance).
كل الحالة بتاعته في متغيرات static:

| المتغير | إيه ده |
| --- | --- |
| `_config` | السياسة بتاعتك |
| `_cached` | آخر حكم اتحسب |
| `_inFlight` | الـ Future الشغال دلوقتي (يمنع التنفيذ المزدوج) |
| `_lastReported` | آخر `reference` اتبلّغ عنه (يمنع تكرار التليمتري) |
| `_pathCache` | نتيجة فحص الملفات (يمنع تكرار الـ I/O) |

### الخطوة 2 — `evaluate()`

[device_integrity.dart:97](device_integrity.dart#L97)

```dart
static Future<DeviceIntegrityResult> evaluate({bool force = false, bool deep = false}) async {
  if (!force && !deep && _cached != null) return _cached!;   // (أ) الكاش

  final pending = _inFlight;
  if (pending != null) return pending;                       // (ب) لو فيه واحد شغال، اشترك فيه

  if (deep) _pathCache.clear();                              // (ج) فحص عميق = امسح كاش المسارات

  final future = _run();
  _inFlight = future;
  try {
    final result = await future;
    _cached = result;
    _report(result);                                         // (د) بلّغ الـ callbacks
    return result;
  } finally {
    _inFlight = null;
  }
}
```

الأربع نقط دول كل واحدة بتحل مشكلة:

- **(أ)** الفحص غالي؛ متعملوش مرتين من غير سبب.
- **(ب)** `main()` بينادي `evaluate()`، و `DeviceGate.initState` بينادي `_recheck()`.
  الاتنين ممكن يتنططوا مع بعض. `_inFlight` بيخلي التاني يستنى الأول بدل ما
  يشغّل كل الـ probes تاني.
- **(ج)** الفرق بين `force` و `deep`: `force` بيعيد الفحوصات الرخيصة (خيارات
  المطور مثلاً — دي بتتغير وقت التشغيل فعلاً). `deep` بيعيد كمان فحص الـ 50
  مسار على الديسك — ودي **ما بتتغيرش** تحت تطبيق شغال، عشان كده الـ resume
  بيستخدم `force` بس، وزرار "check again" هو اللي بيستخدم `deep`.
- **(د)** `_report` بيتنادي هنا مش جوه المحرك، عشان يتنادي مرة واحدة لكل حكم.

### الخطوة 3 — `_run()`: شبكة الأمان الأخيرة

[device_integrity.dart:144](device_integrity.dart#L144)

```dart
static Future<DeviceIntegrityResult> _run() async {
  try {
    return await _evaluate().timeout(_config.evaluationTimeout);
  } catch (error, stackTrace) {
    _config.onProbeError?.call('evaluate', error, stackTrace);
    return const DeviceIntegrityResult.allowed();
  }
}
```

**سياسة "فشل مفتوح"**: لو حصل exception، اسمح. عمر ما هنقفل تطبيق في وش يوزر
دافع بسبب باج عندنا. بس خد بالك — ده هنا **للمحرك نفسه**؛ الـ probes الفردية
ليها حمايتها الخاصة (الخطوة 5).

### الخطوة 4 — `_evaluate()`: توجيه المنصة

[device_integrity.dart:155](device_integrity.dart#L155)

```dart
static Future<DeviceIntegrityResult> _evaluate() async {
  // مفيش short-circuit للـ bypass هنا — مقصود، شوف قسم 5

  if (kIsWeb) return _blocked(unsupportedPlatform, ['platform:web']);

  final probe = _probe;
  if (!probe.isAndroid && !probe.isIOS) {
    return _blocked(unsupportedPlatform, ['platform:${probe.operatingSystem}']);
  }

  return probe.isAndroid ? _evaluateAndroid(probe) : _evaluateIOS(probe);
}
```

### الخطوة 5 — `_ask()`: عزل كل probe لوحدها

[device_integrity.dart:188](device_integrity.dart#L188)

**دي أهم دالة في الملف كله.**

```dart
static Future<T?> _ask<T>(String name, Future<T> Function() body) async {
  try {
    return await body().timeout(_config.probeTimeout);
  } catch (error, stackTrace) {
    _config.onProbeError?.call(name, error, stackTrace);
    return null;      // ← "مش عارف"، مش "نضيف"
  }
}
```

ليه دي مهمة؟ لو الـ `try` كان ملفوف حوالين التقييم كله (زي النسخة القديمة)،
يبقى أي حد يقدر يخلّي platform channel واحدة ترمي → التقييم كله بيترمي →
`_run` بيمسك → **البوابة بتتفتح بالكامل**، حتى لو `file:bluestacks` كان اتلقى
بالفعل.

مع `_ask`، الـ probe اللي فشلت بترجّع `null`، والمنادي بيحط القيمة الآمنة
مكانها، **وباقي الإشارات في نفس الفئة بتفضل قايمة**:

```dart
if (await _ask('isRealDevice', probe.isRealDevice) == false)
  const DeviceSignal('safe_device:emulator', SignalWeight.strong),
```

`== false` مش `!` — لأن `null` (فشل) لازم يبقى مختلف عن `false` (إميوليتور).

### الخطوة 6 — جمع الإشارات

[device_integrity.dart:239](device_integrity.dart#L239)

`_evaluateAndroid` بيمشي على أربع فئات بالترتيب، وأول واحدة تعدّي العتبة بتوقف
كل حاجة:

```
1. WSA / ويندوز        → unsupportedPlatform
2. إميوليتور            → emulator
3. روت / test-keys      → compromised
4. تلاعب بالتطبيق       → tampered      (مطفي by default)
5. خيارات المطور        → developerMode (مطفي by default)
```

كل فئة بتبني `List<DeviceSignal>`. مثال من فئة الإميوليتور:

```dart
final verdict = _decide(
  DeviceBlockReason.emulator,
  [
    if (info != null) ..._androidBuildSignals(info),      // من Build
    ...await _artifactSignals({...emulatorArtifacts}),    // من الديسك
    if (info != null && !info.isPhysicalDevice)
      const DeviceSignal('build:not-physical', SignalWeight.strong),
    if (await _ask('isRealDevice', probe.isRealDevice) == false)
      const DeviceSignal('safe_device:emulator', SignalWeight.strong),
  ],
  observed,
);
if (verdict != null) return verdict;
```

لاحظ `if (info != null)` قدام كل حاجة محتاجة `Build`: لو الـ probe دي فشلت،
فحص الملفات لسه شغال. ده الـ fail-open الموضعي في التطبيق العملي.

### الخطوة 7 — `_decide()`: الحسبة

[device_integrity.dart:204](device_integrity.dart#L204)

```dart
static DeviceIntegrityResult? _decide(reason, signals, observed) {
  if (!_config.blocks(reason)) return null;         // (أ) الفئة دي مطفية أصلاً؟

  final seen = <String>{};
  final kept = <DeviceSignal>[];
  for (final signal in signals) {
    if (_config.isIgnored(signal.id) || !seen.add(signal.id)) continue;  // (ب) فلترة
    kept.add(_config.weigh(signal));                                     // (ج) إعادة وزن
  }
  if (kept.isEmpty) return null;

  observed.addAll(kept);
  final score = scoreOf(kept);                                           // (د) الجمع
  if (score < _config.blockThreshold) return null;                       // (هـ) العتبة
  return DeviceIntegrityResult(reason, List.unmodifiable(kept), score: score);
}
```

- **(ب)** `isIgnored` بيشوف الـ id بالظبط، وبيشوف البادئة كمان: `{'abi:'}`
  بتلغي `abi:x86_64+x86` وأي إشارة `abi:` تانية.
- **(ج)** `weigh` بيدوّر على override في `signalWeights` بالـ id أو بالفئة.
- **(هـ)** رجوع `null` معناها **"مش كفاية، كمّل فحص"** — مش "الجهاز نضيف".

هنا بالظبط الفرق بين النسخة القديمة والجديدة. قبل كده أي إشارة واحدة كانت
تبلّك. دلوقتي:

```
Galaxy S23:  bootloader:unknown(30)                    =  30  → كمّل، وفي الآخر: عدّى
BlueStacks:  file:bluestacks(100)                      = 100  → اتبلك
إميوليتور:    safe_device(60) + not-physical(60)        = 120  → اتبلك
```

الأوزان معرّفة في [device_signal.dart](device_signal.dart):

```dart
enum SignalWeight {
  conclusive(100),   // مستحيل على جهاز ريتيل. بيبلّك لوحده
  strong(60),        // موثوق، بس فيه طريق false positive. اتنين بيبلّكوا
  weak(30),          // بيظهر على أجهزة حقيقية كمان. تعزيز بس
}
```

**إزاي بنقرر وزن إشارة؟** بنسأل: "هل ممكن دي تظهر على جهاز حقيقي دافع؟"

- `file:bluestacks` — `/data/bluestacks.prop` مش هيتخلق على تليفون. → `conclusive`
- `safe_device:emulator` — مكتبة `safe_device` **بتبلع أخطاءها وترجّع `false`**،
  يعني بلَّجن فشل في التسجيل بيبان زي إميوليتور. → `strong` (لازم تعزيز)
- `bootloader:unknown` — نص أجهزة السوق. → `weak`

### الخطوة 8 — فحص الملفات

[device_integrity.dart:535](device_integrity.dart#L535)

```dart
static Future<List<DeviceSignal>> _artifactSignals(Map<String, String> artifacts) async {
  final labels = <String>{};
  await Future.wait(
    artifacts.entries.map((entry) async {
      if (await _exists(entry.key)) labels.add(entry.value);
    }),
  );
  return [for (final label in labels) DeviceSignal('file:$label', SignalWeight.conclusive)];
}
```

`Future.wait` = الـ 35 مسار بيتفحصوا **بالتوازي**، مش واحد ورا التاني.
و `_exists` بيكاش النتيجة في `_pathCache`:

```dart
static Future<bool> _exists(String path) async {
  final cached = _pathCache[path];
  if (cached != null) return cached;
  var present = false;
  try {
    present = await _probe.pathExists(path).timeout(_config.probeTimeout);
  } catch (_) {
    // مسار مش مقروء — نفس معنى "مش موجود"
  }
  _pathCache[path] = present;
  return present;
}
```

الـ `Set<String> labels` مهم: 4 مسارات مختلفة لـ BlueStacks بيدّوا إشارة واحدة
`file:bluestacks`، مش أربعة (وإلا كانوا 400 نقطة من حاجة واحدة).

### الخطوة 9 — النتيجة

[device_integrity_result.dart](device_integrity_result.dart)

```dart
class DeviceIntegrityResult {
  final DeviceBlockReason reason;    // none / emulator / compromised / ...
  final List<DeviceSignal> evidence; // الإشارات بأوزانها
  final int score;                   // مجموع النقط

  bool get isAllowed => reason == DeviceBlockReason.none;
  List<String> get signals => [for (final s in evidence) s.id];
  String get reference => 'emulator[130]: build:bluestacks, file:bluestacks';
}
```

**حاجة مهمة**: النتيجة اللي `isAllowed == true` كمان بتحمل `evidence`. جهاز جاب
60 من 100 هو بالظبط اللي عايز تشوفه في التليمتري **قبل** ما تشدّ الأوزان.

### الخطوة 10 — `DeviceGate` بيرسم

[device_gate.dart](device_gate.dart)

```dart
@override
Widget build(BuildContext context) {
  final result = DeviceIntegrity.verdict;
  if (result == null) return _pending(context);            // (أ) لسه مفيش حكم
  if (result.isAllowed) return widget.child;               // (ب) عدّى
  if (widget.allowWhen?.call() ?? false) return widget.child;  // (ج) استثناء
  return DeviceBlockedScreen(...);                         // (د) اتبلك
}
```

- **(أ)** لو المضيف نسي يعمل `evaluate()` قبل `runApp`، بنرسم شاشة فاضية
  (أو `pendingBuilder`) — **مش** محتوى التطبيق. محتوى التطبيق ما يبانش ولا فريم
  واحد على جهاز على وشك يتبلك.
- **(ب)** `verdict` مش `lastResult` — الفرق ده هو موضوع القسم الجاي.

---

## 3. سيناريو: اللوجين الأول ثم إعادة التقييم

ده اللي انت سألت عنه. الحل ما فيهوش إعادة فحص للجهاز أصلاً — وده المفتاح.

### التمييز اللي بيحل المشكلة

| | إيه ده | بيتغير امتى |
| --- | --- | --- |
| `DeviceIntegrity.lastResult` | حكم عن **الجهاز** | لما تنادي `evaluate()` |
| `DeviceIntegrity.verdict` | حكم عن **اليوزر ده دلوقتي** | كل مرة تقراه |

```dart
static DeviceIntegrityResult? get verdict =>
    isBypassed ? const DeviceIntegrityResult.allowed() : _cached;
```

الجهاز ما اتغيرش لما اليوزر عمل لوجين. اللي اتغير هو **السياسة**: مين مسموح له
يتجاهل الحكم. عشان كده `verdict` بيتحسب كل قراية بدل ما يتكاش.

### الوصلة

```dart
// في main()
DeviceIntegrity.configure(DeviceIntegrityConfig(
  bypass: () => session.user?.isReviewer ?? false,   // ← بيتقرا كل رسمة
));
await DeviceIntegrity.evaluate();

// في MaterialApp.builder
DeviceGate(
  allowWhen: () => !session.hasAccount,   // فتح على أول تسطيب
  refreshOn: session,                     // اقفل/افتح لحظة اللوجين
  child: child!,
)
```

### الترتيب الزمني

```
┌────────────────────────────────────────────────────────────────┐
│ 1. main()                                                      │
│    evaluate() → BlueStacks اتكشف                               │
│    lastResult = emulator[100]                                  │
│    verdict    = emulator[100]   (مفيش bypass لسه)              │
├────────────────────────────────────────────────────────────────┤
│ 2. أول رسمة                                                    │
│    verdict مش allowed                                          │
│    → allowWhen() = !hasAccount = true                          │
│    → شاشة اللوجين بتظهر ✅                                     │
├────────────────────────────────────────────────────────────────┤
│ 3. اليوزر عمل لوجين، السيرفر رجّع isReviewer                    │
│    session.notifyListeners()                                   │
│    → refreshOn بيسمع → setState → إعادة رسم                    │
│    → مفيش أي probe بيتنادي. الجهاز ما اتغيرش.                  │
├────────────────────────────────────────────────────────────────┤
│ 4-أ. يوزر عادي (isReviewer = false)                            │
│    verdict    = emulator[100]                                  │
│    allowWhen  = !hasAccount = false                            │
│    → شاشة البلوك ✅                                            │
├────────────────────────────────────────────────────────────────┤
│ 4-ب. مراجع متجر (isReviewer = true)                            │
│    isBypassed = true                                           │
│    verdict    = allowed                                        │
│    → التطبيق شغال ✅                                           │
└────────────────────────────────────────────────────────────────┘
```

**لاحظ**: مفيش `evaluate()` تاني في الخطوة 3. الفحص بيحصل مرة واحدة، والسياسة
بتتقرا كل رسمة.

### الباج اللي كان هنا

في نسخة أولانية كان المحرك بيعمل:

```dart
static Future<DeviceIntegrityResult> _evaluate() async {
  if (isBypassed) return const DeviceIntegrityResult.allowed();   // ← غلط
  ...
}
```

يعني حكم المراجع "allowed" كان بيتكاش. لما يعمل **logout**، `bypass` بيرجع
`false`، بس الكاش لسه بيقول allowed → **البوابة فاضلة مفتوحة على إميوليتور
لأي حد يستخدم التليفون بعده**.

الحل: الكاش يوصف **الجهاز** دايماً، والاستثناء يتطبّق وقت الرسم. فيه تست
مثبّت ده: `signing out closes the gate behind a reviewer`.

### `hasAccount` لازم يكون sticky

خد بالك من الفرق:

```dart
allowWhen: () => !session.isSignedIn,   // ❌ خطر
allowWhen: () => !session.hasAccount,   // ✅
```

الأولانية معناها إن أي حد يدوس "تسجيل خروج" بيفتح البوابة تاني — بقت ثغرة
دائمة. `hasAccount` معناها "حد عمل حساب على التسطيبة دي مرة على الأقل" وما
بتترجعش بالـ logout.

### السيرفر هو الحكم الحقيقي

`isReviewer` ده `bool` في SharedPreferences. على جهاز مروّت (وهو اللي احنا
بنمنعه أصلاً) تغيير المفتاح ده بيفتح كل حاجة. الوصلة اللي فوق كويسة كـ UX،
لكن الحماية الحقيقية إن **السيرفر يرفض يسلّم المحتوى** — ابعت
`DeviceIntegrity.lastResult?.reference` في هيدر مع كل ريكوست وخلي السيرفر
يقرر.

---

## 4. خريطة الملفات

| الملف | مسؤول عن | تلمسه لما |
| --- | --- | --- |
| [device_signal.dart](device_signal.dart) | الأوزان والنقط | تغيّر مودل الثقة نفسه |
| [device_probe.dart](device_probe.dart) | كل الـ plugins و `dart:io` | تضيف مصدر بيانات جديد |
| [device_fingerprints.dart](device_fingerprints.dart) | الجداول (const، مفيش منطق) | **الأغلب** — إميوليتور جديد |
| [device_integrity_config.dart](device_integrity_config.dart) | السياسة | تضيف خيار للمضيف |
| [device_integrity.dart](device_integrity.dart) | المحرك | تضيف نوع فحص جديد |
| [device_integrity_result.dart](device_integrity_result.dart) | النتيجة + الأسباب | تضيف سبب بلوك |
| [device_gate.dart](device_gate.dart) | الويدجت | تغيّر سلوك البوابة |
| [device_blocked_screen.dart](device_blocked_screen.dart) | شاشة البلوك | شكل/نصوص |

---

## 5. وصفات

### إضافة إميوليتور جديد

في [device_fingerprints.dart](device_fingerprints.dart) بس — من غير ما تلمس
المحرك:

```dart
static const Set<String> emulatorNames = {
  ...,
  'newplayer',        // بيتطابق كـ substring في أي حقل Build → conclusive
};

static const Map<String, String> emulatorArtifacts = {
  ...,
  '/system/bin/newplayerd': 'newplayer',
};
```

وبعدين تست في [test/device_integrity_test.dart](test/device_integrity_test.dart):

```dart
test('NewPlayer is caught', () async {
  final result = await evaluateWith(configFor(FakeDeviceProbe(
    android: const AndroidProbeInfo(hardware: 'newplayer', /* ... */),
  )));
  expect(result.reason, DeviceBlockReason.emulator);
});
```

### إصلاح false positive من غير ديبلوي

```dart
ignoredSignals: {'hardware:intel'},                       // شيلها خالص
signalWeights: {'safe_device:emulator': SignalWeight.weak}, // أو نزّل وزنها بس
```

التاني أحسن — بتفضل مفيدة كتعزيز.

### إضافة فحص جديد بالكامل

1. زوّد ميثود في `DeviceProbe` + نفّذها في `PlatformDeviceProbe`.
2. زوّدها في `FakeDeviceProbe` في التستات.
3. في المحرك، ضيف الإشارة جوه `_ask` بالوزن المناسب.
4. لو نوع مختلف: `DeviceBlockReason` جديد + `blocks()` + `DeviceGateStrings`.

### فهم ليه جهاز اتبلك

`result.reference` بيقولك كل حاجة:

```
emulator[160]: build:not-physical, safe_device:emulator, hardware:qemu
         ^^^   ^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^
      المجموع      60                    60                  ← دي عدّت العتبة
```

---

## 6. أسئلة متكررة

**ليه `DeviceIntegrity` static مش instance؟**
عشان يتقرا من أي مكان من غير ما تمرّره — من interceptor في الشبكة، من isolate،
من ويدجت جوه الشجرة. التكلفة إنه بيحتاج `reset()` بين التستات.

**ليه فيه `_ask` و برضه `try` في `_run`؟**
`_ask` للـ probes (متوقع تفشل). `_run` للمحرك نفسه (باج عندنا). لو `_ask`
شغالة صح، `_run` عمره ما هيمسك حاجة.

**ليه `verdict` بيرجّع `null`؟**
`null` = "لسه مفيش حكم" (`evaluate` ما خلصتش). البوابة بترسم `pendingBuilder`.
`allowed` = "اتفحص وعدّى". الاتنين مختلفين تماماً.

**الـ resume بيعمل فحص كامل؟**
لأ. `force: true` بس — الفحوصات الرخيصة. المسارات على الديسك ما بتتغيرش تحت
تطبيق شغال، و 50 stat call كل مرة الابن آدم يفتح التطبيق ده jank حقيقي.
زرار "check again" هو اللي بيعمل `deep: true`.

**ليه الموديول مش بيتكمبل على الويب؟**
[device_probe.dart](device_probe.dart) بيعمل `import 'dart:io'` من غير شرط.
مقصود: بناء ويب بيفشل وقت الكمبايل بدل ما يشتغل ويتفتح من أي براوزر. فرع
`kIsWeb` في المحرك مفيد بس لو حطيت `DeviceProbe` خاص بيك.
