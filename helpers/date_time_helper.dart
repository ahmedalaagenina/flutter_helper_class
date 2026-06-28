import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeHelper {
  static String fromDateToString(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  static DateTime fromStringToDate(String dateTime) {
    var parse = DateTime.parse(dateTime);
    return DateTime(parse.year, parse.month, parse.day);
    // return Intl.withLocale(
    //     'en', () => DateFormat("yyyy-MM-dd").parse(dateTime));
  }

  static String fromStringToTime(String dateTime) {
    var listTime = dateTime.split(':');
    var parse = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      int.parse(listTime[0]),
      int.parse(listTime[1]),
    );
    return DateFormat('hh:mm a').format(parse);
  }

  static String fromStringToDataAndTime(String? dateTime) {
    if (dateTime == null) {
      return DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now());
    }
    return DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.parse(dateTime));
  }

  static String fromStringToDayAndDataAndTime(String? dateTime) {
    if (dateTime == null) {
      return DateFormat('EEEE, dd/MM/yyyy, hh:mm a').format(DateTime.now());
    }
    return DateFormat(
      'EEEE, dd/MM/yyyy, hh:mm a',
    ).format(DateTime.parse(dateTime));
  }

  static DateTime stringToData(String dateTime) {
    return DateFormat('yyyy-MM-dd').parse(dateTime);
  }

  static String stringToTime(String dateTime, Locale locale) {
    List<String> times = dateTime.split(":");
    DateTime time = DateTime(
      0,
      0,
      0,
      int.parse(times[0]),
      int.parse(times[1]),
      int.parse(times[2]),
    );
    return DateFormat('h a', locale.languageCode).format(time);
  }

  static int countDaysInMonth(int year, int month) {
    if (month == DateTime.february) {
      final bool isLeapYear =
          (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const List<int> daysInMonth = [
      31,
      -1,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ];
    return daysInMonth[month - 1];
  }

  static String formatExpiresAt(DateTime? expiresAt) {
    if (expiresAt == null) return S.current.noExpiry;

    final differenceInDays = calculateDifferenceInDays(expiresAt);

    if (differenceInDays < 0) {
      return S.current.expired;
    } else if (differenceInDays == 0) {
      return S.current.expiresToday;
    } else if (differenceInDays == 1) {
      return S.current.expiresTomorrow;
    } else if (differenceInDays < 7) {
      return S.current.expiresInDays(differenceInDays);
    } else {
      return S.current.expiresPrefix(
        '${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
      );
    }
  }

  static String getTimeDifferenceFromNow(DateTime dateTime) {
    Duration difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 5) {
      return "Just now";
    } else if (difference.inMinutes < 1) {
      return "${difference.inSeconds}s ago";
    } else if (difference.inHours < 1) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }

  static List<DateTime> getCommonDates(
    List<DateTime> firstDates,
    List<DateTime> secondDates,
  ) {
    Set<DateTime> set1 = Set<DateTime>.from(firstDates);
    Set<DateTime> set2 = Set<DateTime>.from(secondDates);
    Set<DateTime> commonDates = set1.intersection(set2);
    return commonDates.toList();
  }

  static List<DateTime> reArrangeDatesByBefore(List<DateTime> dates) {
    List<DateTime> dateList = dates
        .map((e) => fromStringToDate(e.toString()))
        .toList();

    dateList.sort((a, b) => a.isBefore(b) ? -1 : 1);
    return dateList;
  }

  static List<DateTime> reArrangeDatesByAfter(List<DateTime> dates) {
    List<DateTime> dateList = dates
        .map((e) => fromStringToDate(e.toString()))
        .toList();

    dateList.sort((a, b) => a.isAfter(b) ? -1 : 1);
    return dateList;
  }

  static List<DateTime> getDaysInBetween(DateTime startDate, DateTime endDate) {
    List<DateTime> days = [];
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      days.add(startDate.add(Duration(days: i)));
    }
    return days;
  }

  static int getDifferenceInDays(DateTime startDate, DateTime endDate) {
    List<DateTime> days = [];
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      days.add(startDate.add(Duration(days: i)));
    }
    return days.length;
  }

  static String fromDateToDay(DateTime? dateTime) {
    if (dateTime == null) {
      return DateFormat('EEEE').format(DateTime.now());
    }
    return DateFormat('EEEE').format(dateTime);
  }

  static String fromStringToMonthAndYear(String? dateTime) {
    if (dateTime == null) {
      return DateFormat('MMMM, yyyy').format(DateTime.now());
    }
    return DateFormat('MMMM, yyyy').format(DateTime.parse(dateTime));
  }

  /// From saturday to friday
  static DateTime findFirstDateOfTheWeek(DateTime dateTime) {
    return dateTime.subtract(Duration(days: 1 + (dateTime.weekday % 7)));
  }

  static DateTime findLastDateOfTheWeek(DateTime dateTime) {
    return dateTime.add(
      Duration(days: DateTime.daysPerWeek - (dateTime.weekday % 7) - 2),
    );
  }

  static DateTime findFirstDateOfPreviousWeek(DateTime dateTime) {
    final DateTime sameWeekDayOfLastWeek = dateTime.subtract(
      const Duration(days: 7),
    );
    return findFirstDateOfTheWeek(sameWeekDayOfLastWeek);
  }

  static DateTime findLastDateOfPreviousWeek(DateTime dateTime) {
    final DateTime sameWeekDayOfLastWeek = dateTime.subtract(
      const Duration(days: 7),
    );
    return findLastDateOfTheWeek(sameWeekDayOfLastWeek);
  }

  static DateTime findFirstDateOfNextWeek(DateTime dateTime) {
    final DateTime sameWeekDayOfNextWeek = dateTime.add(
      const Duration(days: 7),
    );
    return findFirstDateOfTheWeek(sameWeekDayOfNextWeek);
  }

  static DateTime findLastDateOfNextWeek(DateTime dateTime) {
    final DateTime sameWeekDayOfNextWeek = dateTime.add(
      const Duration(days: 7),
    );
    return findLastDateOfTheWeek(sameWeekDayOfNextWeek);
  }

  static DateTime findFirstDateOfTheMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, 1);
  }

  static DateTime findLastDateOfTheMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month + 1, 0);
  }

  static DateTime findFirstDateOfPreviousMonth(DateTime dateTime) {
    final DateTime prevMonth = DateTime(
      dateTime.year,
      dateTime.month - 1,
      dateTime.day,
    );
    return findFirstDateOfTheMonth(prevMonth);
  }

  static DateTime findLastDateOfPreviousMonth(DateTime dateTime) {
    final DateTime prevMonth = DateTime(
      dateTime.year,
      dateTime.month - 1,
      dateTime.day,
    );
    return findLastDateOfTheMonth(prevMonth);
  }

  static DateTime findFirstDateOfTheYear(DateTime dateTime) {
    return DateTime(dateTime.year, 1, 1);
  }

  static DateTime findLastDateOfTheYear(DateTime dateTime) {
    return DateTime(dateTime.year, 12, 31);
  }

  static DateTime findFirstDateOfPreviousYear(DateTime dateTime) {
    final DateTime prevMonth = DateTime(
      dateTime.year - 1,
      dateTime.month,
      dateTime.day,
    );
    return findFirstDateOfTheYear(prevMonth);
  }

  static DateTime findLastDateOfPreviousYear(DateTime dateTime) {
    final DateTime prevMonth = DateTime(
      dateTime.year - 1,
      dateTime.month,
      dateTime.day,
    );
    return findLastDateOfTheYear(prevMonth);
  }

  static bool isInThisWeek(DateTime dateTime) {
    var firstDateOfTheWeek = findFirstDateOfTheWeek(DateTime.now());
    var lastDateOfTheWeek = findLastDateOfTheWeek(DateTime.now());
    return dateTime.isBetween(from: firstDateOfTheWeek, to: lastDateOfTheWeek);
  }

  static bool isInLastWeek(DateTime dateTime) {
    var firstDateOfTheWeek = findFirstDateOfPreviousWeek(DateTime.now());
    var lastDateOfTheWeek = findLastDateOfPreviousWeek(DateTime.now());
    return dateTime.isBetween(from: firstDateOfTheWeek, to: lastDateOfTheWeek);
  }

  static bool isInThisMonth(DateTime dateTime) {
    var firstDateOfTheMonth = findFirstDateOfTheMonth(DateTime.now());
    var lastDateOfTheMonth = findLastDateOfTheMonth(DateTime.now());
    return dateTime.isBetween(
      from: firstDateOfTheMonth,
      to: lastDateOfTheMonth,
    );
  }

  static bool isInLastMonth(DateTime dateTime) {
    var firstDateOfTheMonth = findFirstDateOfPreviousMonth(DateTime.now());
    var lastDateOfTheMonth = findLastDateOfPreviousMonth(DateTime.now());
    return dateTime.isBetween(
      from: firstDateOfTheMonth,
      to: lastDateOfTheMonth,
    );
  }

  static bool isInThisYear(DateTime dateTime) {
    var firstDateOfTheYear = findFirstDateOfTheYear(DateTime.now());
    var lastDateOfTheYear = findLastDateOfTheYear(DateTime.now());
    return dateTime.isBetween(from: firstDateOfTheYear, to: lastDateOfTheYear);
  }

  static bool isInLastYear(DateTime dateTime) {
    var firstDateOfPreviousYear = findFirstDateOfPreviousYear(DateTime.now());
    var lastDateOfPreviousYear = findLastDateOfPreviousYear(DateTime.now());
    return dateTime.isBetween(
      from: firstDateOfPreviousYear,
      to: lastDateOfPreviousYear,
    );
  }

  /// Returns the difference (in full days) between the provided date and today.
  /// Yesterday : calculateDifference(date) == -1.
  /// Today : calculateDifference(date) == 0.
  /// Tomorrow : calculateDifference(date) == 1.
  static int calculateDifference(DateTime date) {
    DateTime now = DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

extension DateTimeExtension on DateTime {
  bool isAfterOrEqual(DateTime other) {
    return isAtSameMomentAs(other) || isAfter(other);
  }

  bool isBeforeOrEqual(DateTime other) {
    return isAtSameMomentAs(other) || isBefore(other);
  }

  bool isBetween({required DateTime from, required DateTime to}) {
    return isAfterOrEqual(from) && isBeforeOrEqual(to);
  }

  bool isBetweenExclusive({required DateTime from, required DateTime to}) {
    return isAfter(from) && isBefore(to);
  }
}
