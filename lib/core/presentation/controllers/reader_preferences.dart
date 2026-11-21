import 'dart:async';

/// The reading preferences that Settings and an open reader's toolbar both change.
enum ReaderPreference { nightMode, fontSize, lineWrap, pdfContinuous }

class ReaderPreferenceChange {
  final ReaderPreference preference;

  /// bool for [ReaderPreference.nightMode], [ReaderPreference.lineWrap] and
  /// [ReaderPreference.pdfContinuous]; double for [ReaderPreference.fontSize].
  final Object value;
  const ReaderPreferenceChange(this.preference, this.value);
}

/// Live sync (CR-SETTINGS-UX N3) between Settings and readers that are already open (a desktop
/// workspace tab, or Settings on a side pane).
///
/// Persistence stays with `AppSettingsRepository`: whoever changes a value saves it, then announces
/// it here. This carries only changes, never a stored value, so a reader that nobody touched behaves
/// exactly as before and a newly opened one still reads the repository.
class ReaderPreferences {
  ReaderPreferences._();

  static final _controller = StreamController<ReaderPreferenceChange>.broadcast(sync: true);

  static Stream<ReaderPreferenceChange> get changes => _controller.stream;

  static void publish(ReaderPreference preference, Object value) {
    _controller.add(ReaderPreferenceChange(preference, value));
  }
}
