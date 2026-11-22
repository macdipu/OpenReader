/// What the user decided (or has not yet decided) about a copy of a file another app shared into
/// OpenReader (CR-FILE-RELOCATE). Only copies in the app's own folders have one.
enum KeepState {
  /// Not decided yet: the reader was left without answering (for example the app was killed). The
  /// copy is protected like a kept one.
  pending,

  /// The user chose to keep the copy in OpenReader.
  kept,

  /// The user kept the copy and also saved a copy of the file to a place of their own. Protected
  /// like [kept].
  saved;

  static KeepState? fromName(String? name) {
    for (final state in values) {
      if (state.name == name) return state;
    }
    return null;
  }
}

/// How much the app must protect the file behind an indexed document from being cleaned up.
enum CopyProtection {
  /// In Recents, or undecided ([KeepState.pending]). Removed only when the size cap leaves no
  /// other choice, and then it shows as a removed temporary copy.
  recent,

  /// A favorite, or the user chose to keep it ([KeepState.kept], [KeepState.saved]). Never removed
  /// automatically.
  kept,
}

/// What to do with a copy of a file another app shared when its reader is closed (Settings, "When
/// closing a file from another app"). CR-FILE-RELOCATE.
enum SharedCopyAction {
  /// Ask each time (the default).
  ask,

  /// Keep the copy in OpenReader without asking.
  keep,

  /// Remove the copy and its Recents entry without asking.
  remove;

  static SharedCopyAction fromName(String? name) {
    for (final action in values) {
      if (action.name == name) return action;
    }
    return ask;
  }
}
