/// What the user decided (or has not yet decided) about a copy of a file another app shared into
/// OpenReader (CR-FILE-RELOCATE). Only copies in the app's own folders have one.
enum KeepState {
  /// Not decided yet: the reader was left without answering (for example the app was killed). The
  /// copy is protected like a kept one.
  pending,

  /// The user chose to keep the copy in OpenReader.
  kept,

  /// The user saved the file to a folder of their own; the document now points at that file.
  saved;

  static KeepState? fromName(String? name) {
    for (final state in values) {
      if (state.name == name) return state;
    }
    return null;
  }
}
