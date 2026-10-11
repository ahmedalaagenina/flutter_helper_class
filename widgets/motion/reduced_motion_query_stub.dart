// Non-web fallback for `reduced_motion_scope.dart`: on mobile and desktop
// Flutter already maps the OS setting to MediaQuery.disableAnimations.

bool prefersReducedMotion() => false;

/// Returns a function that stops listening.
void Function() listenReducedMotion(void Function(bool reduce) onChange) =>
    () {};
