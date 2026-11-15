class AppErrorHandler {
  static String format(dynamic error) {
    if (error is String) return error;
    
    try {
      if (error?.message != null) return error.message;
      if (error?.toString() != null) return error.toString();
    } catch (_) {}
    
    return 'An unexpected error occurred';
  }
}
