import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ParishProfile {
  final String id;
  final String parishName;
  final String parishNameTagalog;
  final String email;
  final String phone;
  final String priest;
  final String currentPriest;
  final ParishHistory history;
  final List<MassScheduleItem> massSchedule;
  final List<OfficeScheduleItem> officeSchedule;
  final DateTime? lastUpdated;

  ParishProfile({
    required this.id,
    required this.parishName,
    required this.parishNameTagalog,
    required this.email,
    required this.phone,
    required this.priest,
    required this.currentPriest,
    required this.history,
    required this.massSchedule,
    required this.officeSchedule,
    this.lastUpdated,
  });

  factory ParishProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final contactFields = _parseContactFields(data['contact'], data);

    return ParishProfile(
      id: doc.id,
      parishName: data['parishName'] ?? 'Sto. Rosario Parish Church',
      parishNameTagalog: data['parishNameTagalog'] ?? 'Parokya ng Sto. Rosario',
      email: contactFields['email'] ?? '',
      phone: contactFields['phone'] ?? '',
      priest: contactFields['priest'] ?? '',
      currentPriest: contactFields['currentPriest'] ?? '',
      history: _parseHistory(data['history']),
      massSchedule: _parseMassSchedule(
        data['massSchedule'] ?? data['schedule'],
      ),
      officeSchedule: _parseOfficeSchedule(
        data['officeSchedule'] ??
            data['officeHours'] ??
            data['office_schedule'] ??
            data['schedule'],
      ),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  static ParishHistory _parseHistory(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return ParishHistory.fromMap(raw);
    }
    if (raw is List<dynamic>) {
      return ParishHistory(
        introductionTagalog: '',
        introductionEnglish: '',
        timelineEvents: raw.map((item) {
          return HistoryEvent.fromMap(
            item is Map<String, dynamic> ? item : <String, dynamic>{},
          );
        }).toList(),
        heritageTagalog: '',
        heritageEnglish: '',
      );
    }
    if (raw is String) {
      return ParishHistory(
        introductionTagalog: raw,
        introductionEnglish: raw,
        timelineEvents: [],
        heritageTagalog: raw,
        heritageEnglish: raw,
      );
    }
    return ParishHistory.fromMap({});
  }

  static List<MassScheduleItem> _parseMassSchedule(dynamic raw) {
    if (raw is List<dynamic>) {
      return raw.map((item) {
        if (item is Map<String, dynamic>) {
          return MassScheduleItem.fromMap(item);
        }
        if (item is String) {
          return MassScheduleItem(
            tagalogDay: item,
            englishDay: item,
            time: item,
            iconName: 'schedule',
            colorValue: 0xFF2196F3,
            category: MassCategory.daily,
          );
        }
        return MassScheduleItem(
          tagalogDay: '',
          englishDay: '',
          time: '',
          iconName: 'schedule',
          colorValue: 0xFF2196F3,
          category: MassCategory.daily,
        );
      }).toList();
    }

    if (raw is Map<String, dynamic>) {
      final items = <MassScheduleItem>[];
      if (raw['massSchedule'] is List<dynamic>) {
        items.addAll(
          (raw['massSchedule'] as List<dynamic>).map((item) {
            if (item is Map<String, dynamic>) {
              return MassScheduleItem.fromMap(item);
            }
            if (item is String) {
              return MassScheduleItem(
                tagalogDay: item,
                englishDay: item,
                time: item,
                iconName: 'schedule',
                colorValue: 0xFF2196F3,
                category: MassCategory.daily,
              );
            }
            return MassScheduleItem(
              tagalogDay: '',
              englishDay: '',
              time: '',
              iconName: 'schedule',
              colorValue: 0xFF2196F3,
              category: MassCategory.daily,
            );
          }),
        );
      } else if (raw['schedule'] is List<dynamic>) {
        items.addAll(
          (raw['schedule'] as List<dynamic>).map((item) {
            if (item is Map<String, dynamic>) {
              return MassScheduleItem.fromMap(item);
            }
            if (item is String) {
              return MassScheduleItem(
                tagalogDay: item,
                englishDay: item,
                time: item,
                iconName: 'schedule',
                colorValue: 0xFF2196F3,
                category: MassCategory.daily,
              );
            }
            return MassScheduleItem(
              tagalogDay: '',
              englishDay: '',
              time: '',
              iconName: 'schedule',
              colorValue: 0xFF2196F3,
              category: MassCategory.daily,
            );
          }),
        );
      } else {
        if (raw['daily'] is List<dynamic>) {
          items.addAll(
            (raw['daily'] as List<dynamic>).map((item) {
              return MassScheduleItem.fromMap(
                item is Map<String, dynamic> ? item : <String, dynamic>{},
              );
            }),
          );
        }
        if (raw['sunday'] is List<dynamic>) {
          items.addAll(
            (raw['sunday'] as List<dynamic>).map((item) {
              return MassScheduleItem.fromMap(
                item is Map<String, dynamic> ? item : <String, dynamic>{},
              );
            }),
          );
        }
      }
      return items;
    }

    return [];
  }

  static List<OfficeScheduleItem> _parseOfficeSchedule(dynamic raw) {
    if (raw is List<dynamic>) {
      return raw.map((item) {
        if (item is Map<String, dynamic>) {
          return OfficeScheduleItem.fromMap(item);
        }
        if (item is String) {
          return OfficeScheduleItem.fromString(item);
        }
        return OfficeScheduleItem(
          tagalogLabel: '',
          englishLabel: '',
          time: '',
          location: '',
        );
      }).toList();
    }

    if (raw is Map<String, dynamic>) {
      if (raw['officeSchedule'] is List<dynamic>) {
        return _parseOfficeSchedule(raw['officeSchedule']);
      }
      if (raw['officeHours'] is List<dynamic>) {
        return _parseOfficeSchedule(raw['officeHours']);
      }
      if (raw['schedule'] is List<dynamic>) {
        return _parseOfficeSchedule(raw['schedule']);
      }

      final officeItems = <OfficeScheduleItem>[];
      raw.forEach((key, value) {
        if (value is String) {
          officeItems.add(
            OfficeScheduleItem(
              tagalogLabel: key,
              englishLabel: key,
              time: value,
              location: '',
            ),
          );
        } else if (value is Map<String, dynamic>) {
          officeItems.add(OfficeScheduleItem.fromMap(value));
        }
      });
      return officeItems;
    }

    return [];
  }

  static Map<String, String> _parseContactFields(
    dynamic rawContact,
    Map<String, dynamic> data,
  ) {
    final contact = <String, dynamic>{};
    if (rawContact is Map<String, dynamic>) {
      contact.addAll(rawContact);
    } else if (rawContact is String) {
      contact['phone'] = rawContact;
    }

    String lookup(String key, [String? altKey]) {
      final value = contact[key] ??
          (altKey != null ? contact[altKey] : null) ??
          data[key] ??
          (altKey != null ? data[altKey] : null);
      return value?.toString().trim() ?? '';
    }

    return {
      'email': lookup('email'),
      'phone': lookup('phone', 'contact'),
      'priest': lookup('priest'),
      'currentPriest': lookup('currentPriest', 'current_priest'),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'parishName': parishName,
      'parishNameTagalog': parishNameTagalog,
      'contact': {
        'email': email,
        'phone': phone,
        'priest': priest,
        'currentPriest': currentPriest,
      },
      'history': history.toMap(),
      'massSchedule': massSchedule.map((item) => item.toMap()).toList(),
      'officeSchedule': officeSchedule.map((item) => item.toMap()).toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

class ParishHistory {
  final String introductionTagalog;
  final String introductionEnglish;
  final List<HistoryEvent> timelineEvents;
  final String heritageTagalog;
  final String heritageEnglish;

  ParishHistory({
    required this.introductionTagalog,
    required this.introductionEnglish,
    required this.timelineEvents,
    required this.heritageTagalog,
    required this.heritageEnglish,
  });

  factory ParishHistory.fromMap(Map<String, dynamic> map) {
    return ParishHistory(
      introductionTagalog: map['introductionTagalog'] ?? '',
      introductionEnglish: map['introductionEnglish'] ?? '',
      timelineEvents:
          (map['timelineEvents'] as List<dynamic>?)
              ?.map((event) => HistoryEvent.fromMap(event))
              .toList() ??
          [],
      heritageTagalog: map['heritageTagalog'] ?? '',
      heritageEnglish: map['heritageEnglish'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'introductionTagalog': introductionTagalog,
      'introductionEnglish': introductionEnglish,
      'timelineEvents': timelineEvents.map((event) => event.toMap()).toList(),
      'heritageTagalog': heritageTagalog,
      'heritageEnglish': heritageEnglish,
    };
  }
}

class HistoryEvent {
  final String year;
  final String titleTagalog;
  final String titleEnglish;
  final String noteTagalog;
  final String noteEnglish;
  final List<String> descriptionsTagalog;
  final List<String> descriptionsEnglish;

  HistoryEvent({
    required this.year,
    required this.titleTagalog,
    required this.titleEnglish,
    required this.noteTagalog,
    required this.noteEnglish,
    required this.descriptionsTagalog,
    required this.descriptionsEnglish,
  });

  factory HistoryEvent.fromMap(Map<String, dynamic> map) {
    final note = map['note'] ?? '';
    final englishNote = map['noteEnglish'] ?? map['note'] ?? '';
    final descriptionsTagalog =
        (map['descriptionsTagalog'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        (note.isNotEmpty ? [note.toString()] : []);
    final descriptionsEnglish =
        (map['descriptionsEnglish'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        (englishNote.isNotEmpty ? [englishNote.toString()] : []);

    return HistoryEvent(
      year: map['year'] ?? '',
      titleTagalog:
          map['titleTagalog'] ?? map['titleEnglish'] ?? note.toString(),
      titleEnglish:
          map['titleEnglish'] ?? map['titleTagalog'] ?? note.toString(),
      noteTagalog: note.toString(),
      noteEnglish: englishNote.toString(),
      descriptionsTagalog: descriptionsTagalog,
      descriptionsEnglish: descriptionsEnglish,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'titleTagalog': titleTagalog,
      'titleEnglish': titleEnglish,
      'descriptionsTagalog': descriptionsTagalog,
      'descriptionsEnglish': descriptionsEnglish,
    };
  }
}

enum MassCategory { daily, sunday }

class MassScheduleItem {
  final String tagalogDay;
  final String englishDay;
  final String time;
  final String iconName; // Store icon as string
  final int colorValue; // Store color as int
  final MassCategory category;

  MassScheduleItem({
    required this.tagalogDay,
    required this.englishDay,
    required this.time,
    required this.iconName,
    required this.colorValue,
    required this.category,
  });

  // Helper to get IconData from string
  IconData get icon {
    switch (iconName) {
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'schedule':
        return Icons.schedule;
      default:
        return Icons.schedule;
    }
  }

  // Helper to get Color from int
  Color get color => Color(colorValue);

  String label(bool isTagalog) => isTagalog ? tagalogDay : englishDay;

  factory MassScheduleItem.fromMap(Map<String, dynamic> map) {
    final rawCategory = map['category'] ?? map['type'];
    MassCategory category = MassCategory.daily;

    if (rawCategory != null) {
      if (rawCategory is int) {
        category = MassCategory
            .values[rawCategory.clamp(0, MassCategory.values.length - 1)];
      } else if (rawCategory is String) {
        category = MassCategory.values.firstWhere(
          (item) => item.name.toLowerCase() == rawCategory.toLowerCase(),
          orElse: () => MassCategory.daily,
        );
      }
    } else {
      // If category is not provided in the DB, infer it from day/label text.
      final dayText =
          (map['tagalogDay'] ??
                  map['englishDay'] ??
                  map['day'] ??
                  map['label'] ??
                  '')
              .toString()
              .toLowerCase();

      final sundayKeywords = ['sunday', 'linggo', 'domingo', 'sun'];
      if (sundayKeywords.any((k) => dayText.contains(k))) {
        category = MassCategory.sunday;
      } else {
        category = MassCategory.daily;
      }
    }

    String tagalogDay =
        map['tagalogDay'] ?? map['dayTagalog'] ?? map['day'] ?? '';
    String englishDay =
        map['englishDay'] ?? map['dayEnglish'] ?? map['day'] ?? '';
    String time = map['time'] ?? map['scheduleTime'] ?? '';

    // If the day/label contains an embedded time (e.g. "Sunday at 8:00 AM" or "Sunday from 8 to 5"), extract it.
    final dayCombined = (englishDay.isNotEmpty ? englishDay : tagalogDay)
        .toString();
    final atTimeRegex = RegExp(
      r"\bat\s*(\d{1,2}(?::\d{2})?(?:\s*[AaPp][Mm])?)",
      caseSensitive: false,
    );
    final fromRangeRegex = RegExp(
      r"\bfrom\s*(\d{1,2}(?::\d{2})?(?:\s*[AaPp][Mm])?)\s*(?:to|\-|â€“|â€”)?\s*(\d{1,2}(?::\d{2})?(?:\s*[AaPp][Mm])?)?",
      caseSensitive: false,
    );

    var match = atTimeRegex.firstMatch(dayCombined);
    if (match != null) {
      final extracted = match.group(1) ?? '';
      if (time.isEmpty) time = normalizeSimpleTime(extracted);
      final cleaned = dayCombined.replaceAll(match.group(0)!, '').trim();
      if (englishDay.isNotEmpty) {
        englishDay = cleaned;
      } else {
        tagalogDay = cleaned;
      }
    } else {
      final fromMatch = fromRangeRegex.firstMatch(dayCombined);
      if (fromMatch != null) {
        final left = fromMatch.group(1) ?? '';
        final right = fromMatch.group(2) ?? '';
        if (time.isEmpty) {
          if (right.isNotEmpty) {
            time =
                '${normalizeSimpleTime(left)} to ${normalizeSimpleTime(right)}';
          } else {
            time = normalizeSimpleTime(left);
          }
        }
        final cleaned = dayCombined.replaceAll(fromMatch.group(0)!, '').trim();
        if (englishDay.isNotEmpty) {
          englishDay = cleaned;
        } else {
          tagalogDay = cleaned;
        }
      }
    }

    return MassScheduleItem(
      tagalogDay: tagalogDay,
      englishDay: englishDay,
      time: time,
      iconName: map['iconName'] ?? map['icon'] ?? 'schedule',
      colorValue: map['colorValue'] ?? map['color'] ?? 0xFF2196F3,
      category: category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tagalogDay': tagalogDay,
      'englishDay': englishDay,
      'time': time,
      'iconName': iconName,
      'colorValue': colorValue,
      'category': category.index,
    };
  }
}

// Normalize simple time inputs (used by both Mass and Office parsers)
String normalizeSimpleTime(String input) {
  var s = input.toString().trim();
  if (s.isEmpty) return '';
  // Normalize common range connectors like 'from 9 to 5', '9-5', '9 â€“ 5'
  final rangeSepRegex = RegExp(r'\bfrom\b\s*', caseSensitive: false);
  s = s.replaceAll(rangeSepRegex, '');
  // separators: ' to ', '-', 'â€“', 'â€”'
  final sepMatch = RegExp(
    r'\s*(?:to|\-|â€“|â€”)\s*',
    caseSensitive: false,
  ).firstMatch(s);
  if (sepMatch != null) {
    final parts = s.split(
      RegExp(r'\s*(?:to|\-|â€“|â€”)\s*', caseSensitive: false),
    );
    if (parts.length >= 2) {
      final left = normalizeSimpleTime(parts[0]);
      final right = normalizeSimpleTime(parts.sublist(1).join(' to '));
      if (left.isNotEmpty && right.isNotEmpty) return '$left to $right';
    }
  }
  if (RegExp(r'[AaPp][Mm]').hasMatch(s)) return s;
  final digitsOnly = RegExp(r'^(\d{1,2})(?::(\d{2}))?$').firstMatch(s);
  if (digitsOnly != null) {
    final h = int.tryParse(digitsOnly.group(1) ?? '0') ?? 0;
    final m = digitsOnly.group(2) ?? '00';
    final hour = (h <= 12 && h >= 1) ? h : h % 24;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${m.padLeft(2, '0')} $period';
  }
  return s;
}

class OfficeScheduleItem {
  final String tagalogLabel;
  final String englishLabel;
  final String time;
  final String location;
  final String description;

  OfficeScheduleItem({
    required this.tagalogLabel,
    required this.englishLabel,
    required this.time,
    required this.location,
    this.description = '',
  });

  String label(bool isTagalog) => isTagalog ? tagalogLabel : englishLabel;

  factory OfficeScheduleItem.fromMap(Map<String, dynamic> map) {
    String tagalogLabel =
        map['tagalogLabel'] ??
        map['labelTagalog'] ??
        map['nameTagalog'] ??
        map['label'] ??
        '';
    String englishLabel =
        map['englishLabel'] ??
        map['labelEnglish'] ??
        map['nameEnglish'] ??
        map['label'] ??
        '';
    String time =
        map['time'] ??
        map['hours'] ??
        map['scheduleTime'] ??
        map['officeTime'] ??
        '';
    final location = map['location'] ?? map['place'] ?? map['office'] ?? '';
    final description =
        map['description'] ?? map['notes'] ?? map['detail'] ?? '';

    // If label contains "at <time>" or "from X to Y", extract it into the time field.
    final labelCombined =
        (englishLabel.isNotEmpty ? englishLabel : tagalogLabel).toString();
    final atTimeRegex2 = RegExp(
      r"\bat\s*(\d{1,2}(?::\d{2})?(?:\s*[AaPp][Mm])?)",
      caseSensitive: false,
    );
    final fromRangeRegex2 = RegExp(
      r"\bfrom\s*(\d{1,2}(?::\d{2})?(?:\s*[AaPp][Mm])?)\s*(?:to|\-|â€“|â€”)?\s*(\d{1,2}(?::\d{2})?(?:\s*[AaPp][Mm])?)?",
      caseSensitive: false,
    );
    final atMatch = atTimeRegex2.firstMatch(labelCombined);
    if (atMatch != null) {
      final extracted = atMatch.group(1) ?? '';
      if (time.isEmpty) time = normalizeSimpleTime(extracted);
      final cleaned = labelCombined.replaceAll(atMatch.group(0)!, '').trim();
      if (englishLabel.isNotEmpty) {
        englishLabel = cleaned;
      } else {
        tagalogLabel = cleaned;
      }
    } else {
      final fromMatch = fromRangeRegex2.firstMatch(labelCombined);
      if (fromMatch != null) {
        final left = fromMatch.group(1) ?? '';
        final right = fromMatch.group(2) ?? '';
        if (time.isEmpty) {
          if (right.isNotEmpty) {
            time =
                '${normalizeSimpleTime(left)} to ${normalizeSimpleTime(right)}';
          } else {
            time = normalizeSimpleTime(left);
          }
        }
        final cleaned = labelCombined
            .replaceAll(fromMatch.group(0)!, '')
            .trim();
        if (englishLabel.isNotEmpty) {
          englishLabel = cleaned;
        } else {
          tagalogLabel = cleaned;
        }
      }
    }

    return OfficeScheduleItem(
      tagalogLabel: tagalogLabel,
      englishLabel: englishLabel,
      time: time,
      location: location,
      description: description,
    );
  }

  factory OfficeScheduleItem.fromString(String raw) {
    final trimmed = raw.trim();
    final fromRegex = RegExp(r'^(.*?)\s+from\s+(.+)$', caseSensitive: false);
    final atRegex = RegExp(
      r'^(.*)\bat\s*(\d{1,2}(?::\d{2})?(?:\s*[AaPp][Mm])?)',
      caseSensitive: false,
    );

    final fromMatch = fromRegex.firstMatch(trimmed);
    if (fromMatch != null) {
      final label = fromMatch.group(1)?.trim() ?? trimmed;
      final time = normalizeSimpleTime(fromMatch.group(2) ?? '');
      return OfficeScheduleItem(
        tagalogLabel: label,
        englishLabel: label,
        time: time,
        location: '',
      );
    }

    final atMatch = atRegex.firstMatch(trimmed);
    if (atMatch != null) {
      final label = atMatch.group(1)?.trim() ?? trimmed;
      final time = normalizeSimpleTime(atMatch.group(2) ?? '');
      return OfficeScheduleItem(
        tagalogLabel: label,
        englishLabel: label,
        time: time,
        location: '',
      );
    }

    final colonParts = trimmed.split(':').map((p) => p.trim()).toList();
    if (colonParts.length >= 2) {
      final label = colonParts.first;
      final time = colonParts.sublist(1).join(': ').trim();
      return OfficeScheduleItem(
        tagalogLabel: label,
        englishLabel: label,
        time: normalizeSimpleTime(time),
        location: '',
      );
    }

    return OfficeScheduleItem(
      tagalogLabel: raw,
      englishLabel: raw,
      time: raw,
      location: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tagalogLabel': tagalogLabel,
      'englishLabel': englishLabel,
      'time': time,
      'location': location,
      'description': description,
    };
  }
}
