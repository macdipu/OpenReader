/// File paths passed on the command line at launch (desktop "Open with" /
/// `openreader file.pdf`). Set once in `main()`, consumed once by the app
/// shell so a path is never re-opened.
class LaunchArguments {
  LaunchArguments._();

  static List<String> files = const [];

  static List<String> take() {
    final taken = files;
    files = const [];
    return taken;
  }
}
