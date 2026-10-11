// Web implementation for `reduced_motion_scope.dart`, using dart:js_interop
// directly (no package needed for two calls).
import 'dart:js_interop';

@JS('matchMedia')
external _MediaQueryList _matchMedia(String query);

extension type _MediaQueryList._(JSObject _) implements JSObject {
  external bool get matches;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _MediaQueryListEvent._(JSObject _) implements JSObject {
  external bool get matches;
}

const _query = '(prefers-reduced-motion: reduce)';

bool prefersReducedMotion() => _matchMedia(_query).matches;

/// Returns a function that stops listening.
void Function() listenReducedMotion(void Function(bool reduce) onChange) {
  final list = _matchMedia(_query);
  final listener = ((_MediaQueryListEvent event) => onChange(event.matches)).toJS;
  list.addEventListener('change', listener);
  return () => list.removeEventListener('change', listener);
}
