/// How the manager should behave once a patch is available.
enum ShorebirdUpdateMode {
  /// Download the patch in the background and never show any UI.
  ///
  /// The patch is applied the next time the user cold-starts the app. This is
  /// the recommended mode: it works before login, on any screen, and it cannot
  /// interrupt the user.
  silent,

  /// Download the patch in the background, then show a prompt telling the user
  /// the update is ready.
  notifyWhenReady,

  /// Ask the user before downloading anything.
  ///
  /// Use this only if patches are large and you care about metered data.
  askBeforeDownload,
}

/// Behaviour derived from [ShorebirdUpdateMode].
///
/// Both getters switch exhaustively, so adding a mode is a compile error
/// here rather than a silent fall-through into another mode's behaviour.
extension ShorebirdUpdateModeBehavior on ShorebirdUpdateMode {
  /// Whether a patch downloads without waiting for the user to confirm.
  bool get downloadsWithoutAsking => switch (this) {
    ShorebirdUpdateMode.silent => true,
    ShorebirdUpdateMode.notifyWhenReady => true,
    ShorebirdUpdateMode.askBeforeDownload => false,
  };

  /// Whether this mode shows any update UI at all.
  bool get showsPrompts => switch (this) {
    ShorebirdUpdateMode.silent => false,
    ShorebirdUpdateMode.notifyWhenReady => true,
    ShorebirdUpdateMode.askBeforeDownload => true,
  };
}

/// How every prompt is rendered when the mode is not
/// [ShorebirdUpdateMode.silent].
///
/// Applies to both the "update available" prompt and the "update ready"
/// prompt, so the two always match.
enum ShorebirdPromptStyle {
  /// A `MaterialBanner` at the top of the screen. Non-blocking.
  banner,

  /// A modal `AlertDialog`.
  dialog,
}
