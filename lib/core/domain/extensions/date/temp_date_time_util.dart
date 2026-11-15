
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class DateTimeUtils {
  static String formattedDateFromDateTime(
      DateTime dateTime, String desiredDateFormat) {
    final DateFormat outputFormat = DateFormat(desiredDateFormat);
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String formatOfferDate(String? date) {
    initializeDateFormatting('en');
    if (date == null || date == "null") {
      return "";
    }
    final DateFormat inputFormat = DateFormat("yyyy-MM-ddTHH:mm:ssZZZZ");
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat.yMMMMd('en');
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String formatTimeLineDate(String? date) {
    initializeDateFormatting('en');
    if (date == null || date == "null") {
      return "";
    }
    final DateFormat inputFormat = DateFormat("yyyy-MM-ddTHH:mm:ssZZZZ");
    final DateTime dateTime = inputFormat.parseUTC(date).toLocal();
    final DateFormat outputFormat = DateFormat(
      'yyyy-MM-dd, hh:mm a',
    );
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String getTimeFromDisirededFormat(String date, String format) {
    final DateFormat inputFormat = DateFormat("HH:mm:ss");
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat(format);
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String getDateFromDisirededFormat(String date, String format) {
    final DateFormat inputFormat = DateFormat("yyyy-MM-dd");
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat(format);
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String getMonthYearFromDate(String date) {
    final DateFormat inputFormat = DateFormat("yyyy-MM-dd");
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat("d MMM");
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String formatPromoDate(String date) {
    final DateFormat inputFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat("MMM d, yyyy");
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String formatInDate(String date) {
    final DateFormat inputFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat("MMM d");
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String getTimeInHrsAndMnts(String date) {
    final DateFormat inputFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    final DateTime dateTime = inputFormat.parse(date);
    final d12 = DateFormat('hh:mm a').format(dateTime);
    return d12;
  }

  static String formatComplainCreateDate(String date) {
    final DateFormat inputFormat = DateFormat("yyyy-MM-dd HH:mm:ss");
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat("d MMM yyyy");
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String formatProfileDate(DateTime dateTime, String desiredFormate) {
    final DateFormat outputFormat = DateFormat(desiredFormate);
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String getOfferRemainingTime(String dateTime) {
    final startOfNextWeek = DateTime.parse(dateTime);
    final remaining = startOfNextWeek.difference(DateTime.now());
    final days = remaining.inDays;
    final hours = remaining.inHours - remaining.inDays * 24;
    final minutes = remaining.inMinutes - remaining.inHours * 60;
    final formattedRemaining = '${days}d ${hours}h ${minutes}m';
    return formattedRemaining;
  }

  static String getDayFromDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    final DateFormat outputFormat = DateFormat("dd");
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String getMonthFromDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    final DateFormat outputFormat = DateFormat("MMM");
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static String getWeekDayFromDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    final DateFormat outputFormat = DateFormat("EEEE");
    final String dateInString = outputFormat.format(dateTime);
    return dateInString;
  }

  static bool isTheDateIsToday(String date) {
    final DateTime dateTime = DateTime.parse(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dateTime == today ? true : false;
  }

  static String getFormattedDateFromTimestamp(
      int timestamp, String desireFormat) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final d12 = DateFormat(desireFormat).format(date);
    return d12;
  }

  static String getDateFromTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final d12 = DateFormat('dd MMMM, yyyy').format(date);
    return d12;
  }

  static String getTimeFromTimestamp12hFormat(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final d12 = DateFormat('hh:mm a').format(date);
    return d12;
  }

  static DateTime? getDateFromString(String? date, String desireFormat) {
    if (date == null || date.isEmpty) {
      return null;
    }
    final DateFormat inputFormat = DateFormat(desireFormat);
    final DateTime dateTime = inputFormat.parse(date);
    return dateTime;
  }
}
