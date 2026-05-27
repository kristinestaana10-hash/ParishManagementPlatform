/// Represents a scheduling conflict detection result
class SchedulingConflictResult {
  final bool hasConflict;
  final String? conflictingBookingId;
  final String? conflictingSacramentType;
  final String? conflictingUserName;
  final String? conflictingDate;
  final String? conflictingTime;
  final String errorMessage;

  SchedulingConflictResult({
    required this.hasConflict,
    this.conflictingBookingId,
    this.conflictingSacramentType,
    this.conflictingUserName,
    this.conflictingDate,
    this.conflictingTime,
    required this.errorMessage,
  });

  factory SchedulingConflictResult.noConflict() {
    return SchedulingConflictResult(
      hasConflict: false,
      errorMessage: 'No scheduling conflict detected',
    );
  }

  factory SchedulingConflictResult.conflict({
    required String bookingId,
    required String sacramentType,
    required String userName,
    required String date,
    String? time,
    String? message,
  }) {
    return SchedulingConflictResult(
      hasConflict: true,
      conflictingBookingId: bookingId,
      conflictingSacramentType: sacramentType,
      conflictingUserName: userName,
      conflictingDate: date,
      conflictingTime: time,
      errorMessage:
          message ??
          'The selected date and time conflicts with another booking that is approved or pending.',
    );
  }
}

/// Represents a booking for conflict checking
class BookingRecord {
  final String id;
  final String sacramentType;
  final String sacramentTypeKey;
  final String date;
  final String time;
  final String status;
  final String? userName;
  final String? userId;

  BookingRecord({
    required this.id,
    required this.sacramentType,
    required this.sacramentTypeKey,
    required this.date,
    required this.time,
    required this.status,
    this.userName,
    this.userId,
  });

  /// Parse booking from Firestore document
  factory BookingRecord.fromFirestore(String id, Map<String, dynamic> data) {
    final details = data['details'] as Map<String, dynamic>? ?? {};
    final fields = details['fields'] as Map<String, dynamic>? ?? {};

    // Extract date and time from details or document fields
    String date = data['date'] as String? ?? '';
    String time = data['time'] as String? ?? '';

    // Fallback to searching in fields if not found in main document
    if (date.isEmpty) {
      for (final entry in fields.entries) {
        final key = entry.key.toString().toLowerCase();
        final val = entry.value?.toString() ?? '';
        if (key.contains('date') || key.contains('petsa')) {
          final dateMatch = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b').firstMatch(val);
          if (dateMatch != null) {
            date = dateMatch.group(1) ?? '';
            break;
          }
        }
      }
    }

    if (time.isEmpty) {
      for (final entry in fields.entries) {
        final key = entry.key.toString().toLowerCase();
        final val = entry.value?.toString() ?? '';
        if (key.contains('time') || key.contains('oras')) {
          final timeMatch = RegExp(
            r'\b(\d{1,2}:\d{2}\s*(?:[AaPp][Mm])?)\b',
          ).firstMatch(val);
          if (timeMatch != null) {
            time = (timeMatch.group(1) ?? '').trim();
            break;
          }
        }
      }
    }

    return BookingRecord(
      id: id,
      sacramentType: data['sacramentType'] as String? ?? 'Unknown',
      sacramentTypeKey: data['sacramentTypeKey'] as String? ?? '',
      date: date,
      time: time,
      status: data['status'] as String? ?? 'pending',
      userName: data['userName'] as String?,
      userId: data['userId'] as String?,
    );
  }
}

/// Service types that cannot overlap
enum RestrictedServiceType {
  baptism,
  confirmation,
  wedding,
  funeral,
  firstCommunion,
  houseBlessing,
  anointing;

  static const List<String> restrictedServiceKeys = [
    'baptism',
    'confirmation',
    'wedding',
    'funeral',
    'house_blessing',
    'anointing',
  ];

  static bool isRestricted(String sacramentTypeKey) {
    return restrictedServiceKeys.contains(
      sacramentTypeKey.toLowerCase().trim(),
    );
  }

  static bool isMassIntention(String sacramentTypeKey) {
    return sacramentTypeKey.toLowerCase().trim() == 'mass_intention';
  }
}

/// Time slot representation for conflict detection
class TimeSlot {
  final String date; // Format: YYYY-MM-DD
  final String time; // Format: HH:MM AM/PM or HH:MM (24-hour)

  TimeSlot({required this.date, required this.time});

  /// Check if two time slots overlap
  static bool doSlotsOverlap(TimeSlot slot1, TimeSlot slot2) {
    // Different dates = no overlap
    if (slot1.date != slot2.date) {
      return false;
    }

    final slot1Minutes = _parseTimeToMinutes(slot1.time);
    final slot2Minutes = _parseTimeToMinutes(slot2.time);
    if (slot1Minutes != null && slot2Minutes != null) {
      return (slot1Minutes - slot2Minutes).abs() < 60;
    }

    return slot1.time.toLowerCase().trim() == slot2.time.toLowerCase().trim();
  }

  static int? _parseTimeToMinutes(String value) {
    final normalizedValue = value
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .trim();
    final match = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?[\s\u00A0\u202F]*([AaPp][Mm])?\b',
    ).firstMatch(normalizedValue);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '00');
    if (hour == null || minute == null || minute < 0 || minute > 59) {
      return null;
    }

    final meridiem = (match.group(3) ?? '').toLowerCase();
    if (meridiem.isNotEmpty) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'am') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }
    } else if (hour > 23) {
      return null;
    } else if (hour >= 1 && hour <= 5) {
      hour += 12;
    }

    return hour * 60 + minute;
  }

  /// Check if slot is valid (has both date and time)
  bool isValid() {
    return date.isNotEmpty && date.contains('-') && time.isNotEmpty;
  }
}
