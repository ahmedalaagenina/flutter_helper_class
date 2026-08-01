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

  /// Show a banner asking the user before downloading anything.
  ///
  /// Use this only if patches are large and you care about metered data.
  askBeforeDownload,
}

/// How a ready-to-apply patch is surfaced when the mode is not
/// [ShorebirdUpdateMode.silent].
enum ShorebirdReadyPromptStyle {
  /// A `MaterialBanner` at the top of the screen. Non-blocking.
  banner,

  /// A modal, non-dismissible `AlertDialog`.
  dialog,
}
