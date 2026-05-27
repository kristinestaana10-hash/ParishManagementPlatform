# Scheduling Conflict Detection - Usage Examples

## Overview

This document provides code examples for using the Scheduling Conflict Detection System in your Flutter application.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Form Integration](#form-integration)
3. [Real-time Availability](#real-time-availability)
4. [Error Handling](#error-handling)
5. [Admin Features](#admin-features)
6. [Advanced Scenarios](#advanced-scenarios)

## Basic Usage

### Example 1: Simple Conflict Check

```dart
import 'package:sto_rosario_parish_church/core/services/scheduling_conflict_service.dart';

// Check if a booking time is available
Future<void> checkAvailability() async {
  final result = await SchedulingConflictService.instance.checkSchedulingConflict(
    sacramentType: 'Baptism',
    date: '2026-06-15',
    time: '10:00 AM',
  );

  if (result.hasConflict) {
    print('❌ Conflict found!');
    print('Conflicting booking: ${result.conflictingBookingId}');
    print('Message: ${result.errorMessage}');
  } else {
    print('✅ No conflict - time is available');
  }
}
```

### Example 2: Mass Intention Schedule Validation

```dart
// Validate if a Mass Intention time is valid
Future<void> validateMassTime() async {
  final isValid = await SchedulingConflictService.instance
      .validateMassIntentionSchedule(
    date: '2026-05-31',
    time: '6:00 AM',
  );

  if (isValid) {
    print('✅ Valid Mass schedule');
  } else {
    print('❌ No Mass at this time - select another');
  }
}
```

## Form Integration

### Example 3: Submit Booking with Conflict Checking

```dart
import 'package:sto_rosario_parish_church/core/services/firebase_service.dart';
import 'package:sto_rosario_parish_church/core/design/colors.dart';

class BookingSubmitButton extends StatelessWidget {
  final String sacramentType;
  final Map<String, dynamic> bookingDetails;

  const BookingSubmitButton({
    required this.sacramentType,
    required this.bookingDetails,
    Key? key,
  }) : super(key: key);

  Future<void> _submitBooking(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking availability...'),
              ],
            ),
          ),
        ),
      );

      // Submit booking with automatic conflict checking
      await FirebaseService.instance.submitBooking(
        sacramentType: sacramentType,
        details: bookingDetails,
        checkConflict: true, // Enables conflict checking
      );

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      _showSuccessDialog(
        context,
        'Booking submitted successfully!',
        'Please wait for admin approval.',
      );
    } on Exception catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      // Handle specific errors
      final errorMessage = e.toString();

      if (errorMessage.contains('schedule is already occupied')) {
        _showErrorDialog(
          context,
          'Schedule Conflict',
          'This date and time is already booked. Please select another time.',
        );
      } else if (errorMessage.contains('does not match')) {
        _showErrorDialog(
          context,
          'Invalid Mass Schedule',
          'This time is not in the official Mass schedule.',
        );
      } else {
        _showErrorDialog(
          context,
          'Booking Failed',
          errorMessage,
        );
      }
    }
  }

  void _showSuccessDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _submitBooking(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: ParishColors.primaryBlue,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text('Submit Booking'),
    );
  }
}
```

### Example 4: Pre-Submission Validation

```dart
// Show a warning before user submits if a conflict is detected
Future<bool> showConflictWarningIfNeeded(
  BuildContext context,
  String sacramentType,
  Map<String, dynamic> bookingDetails,
) async {
  try {
    final result = await FirebaseService.instance.checkBookingConflict(
      sacramentType: sacramentType,
      details: bookingDetails,
    );

    if (result.hasConflict) {
      // Show warning dialog
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('⚠️ Potential Conflict'),
          content: Text(
            'The selected date and time may already be booked.\n\n'
            'Would you like to select a different time?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Go back
              child: Text('Go Back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Continue
              child: Text('Continue Anyway'),
            ),
          ],
        ),
      ) ?? true;

      return !shouldContinue; // Return true if user wants to proceed
    }

    return true; // No conflict, proceed
  } catch (e) {
    print('Error checking conflict: $e');
    return true; // On error, allow user to proceed
  }
}
```

## Real-time Availability

### Example 5: Display Available Time Slots

```dart
import 'package:flutter/material.dart';
import 'package:sto_rosario_parish_church/core/services/firebase_service.dart';

class TimeSlotPicker extends StatefulWidget {
  final String selectedDate;
  final Function(String) onTimeSelected;

  const TimeSlotPicker({
    required this.selectedDate,
    required this.onTimeSelected,
    Key? key,
  }) : super(key: key);

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  final List<String> allTimeSlots = [
    '6:00 AM',
    '8:00 AM',
    '10:00 AM',
    '12:00 PM',
    '2:00 PM',
    '4:00 PM',
  ];

  List<String> availableSlots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
  }

  Future<void> _loadAvailableSlots() async {
    setState(() => isLoading = true);

    try {
      final available = await FirebaseService.instance.getAvailableTimeSlots(
        date: widget.selectedDate,
        allPossibleTimeSlots: allTimeSlots,
      );

      setState(() {
        availableSlots = available;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading available slots: $e');
      setState(() {
        availableSlots = allTimeSlots; // Show all if error
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Times for ${widget.selectedDate}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allTimeSlots.map((time) {
            final isAvailable = availableSlots.contains(time);
            return FilterChip(
              label: Text(time),
              onSelected: isAvailable
                  ? (_) => widget.onTimeSelected(time)
                  : null,
              backgroundColor: isAvailable
                  ? Colors.white
                  : Colors.grey.shade200,
              labelStyle: TextStyle(
                color: isAvailable
                    ? Colors.blue
                    : Colors.grey,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        Text(
          'Grayed out times are already booked',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
```

### Example 6: Show Booked Dates on Calendar

```dart
class BookingCalendarView extends StatefulWidget {
  final String sacramentType;

  const BookingCalendarView({
    required this.sacramentType,
    Key? key,
  }) : super(key: key);

  @override
  State<BookingCalendarView> createState() => _BookingCalendarViewState();
}

class _BookingCalendarViewState extends State<BookingCalendarView> {
  late Future<List<BookingRecord>> bookingsFuture;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    bookingsFuture = FirebaseService.instance.getBookingsForDate(
      _formatDate(selectedDate),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendar widget
        Text('Select a date to see available times'),
        SizedBox(height: 16),

        // Date picker
        ElevatedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 365)),
            );

            if (picked != null) {
              setState(() {
                selectedDate = picked;
                _loadBookings();
              });
            }
          },
          icon: Icon(Icons.calendar_today),
          label: Text(_formatDate(selectedDate)),
        ),

        SizedBox(height: 16),

        // Show bookings for selected date
        FutureBuilder<List<BookingRecord>>(
          future: bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return Text('Error loading bookings');
            }

            final bookings = snapshot.data ?? [];

            if (bookings.isEmpty) {
              return Text('No bookings for this date - all times available!');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booked times (${bookings.length}):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...bookings.map((booking) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${booking.sacramentType} at ${booking.time}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'By: ${booking.userName}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ],
            );
          },
        ),
      ],
    );
  }
}
```

## Error Handling

### Example 7: Comprehensive Error Handling

```dart
class SafeBookingSubmit {
  static Future<Map<String, dynamic>> submitWithErrorHandling({
    required String sacramentType,
    required Map<String, dynamic> bookingDetails,
    required BuildContext context,
    required bool isTagalog,
  }) async {
    try {
      // Step 1: Pre-flight checks
      print('Step 1: Validating form...');
      _validateBookingDetails(bookingDetails);

      // Step 2: Check for conflicts
      print('Step 2: Checking for scheduling conflicts...');
      final result = await FirebaseService.instance.checkBookingConflict(
        sacramentType: sacramentType,
        details: bookingDetails,
      );

      if (result.hasConflict) {
        return {
          'success': false,
          'error': isTagalog
              ? 'Ang schedule na ito ay nasa kung taon na. Pumili ng ibang oras.'
              : 'This schedule is already occupied. Please choose another time.',
          'errorType': 'conflict',
          'conflictDetails': result,
        };
      }

      // Step 3: Validate Mass schedule if applicable
      if (sacramentType.toLowerCase().contains('mass')) {
        print('Step 3: Validating Mass schedule...');
        final date = _extractDate(bookingDetails);
        final time = _extractTime(bookingDetails);

        final isValidMass = await FirebaseService.instance
            .validateMassIntentionSchedule(
          date: date,
          time: time,
        );

        if (!isValidMass) {
          return {
            'success': false,
            'error': isTagalog
                ? 'Ang piniling oras ay hindi sa official na schedule ng Misa.'
                : 'This time is not in the official Mass schedule.',
            'errorType': 'invalid_mass_schedule',
          };
        }
      }

      // Step 4: Submit booking
      print('Step 4: Submitting booking...');
      await FirebaseService.instance.submitBooking(
        sacramentType: sacramentType,
        details: bookingDetails,
        checkConflict: false, // Already checked above
      );

      return {
        'success': true,
        'message': isTagalog
            ? 'Booking na-submit! Maghintay ng approval ng admin.'
            : 'Booking submitted! Please wait for admin approval.',
      };
    } on FormatException catch (e) {
      return {
        'success': false,
        'error': isTagalog
            ? 'Invalid date or time format: ${e.message}'
            : 'Invalid date or time format: ${e.message}',
        'errorType': 'format_error',
      };
    } on Exception catch (e) {
      return {
        'success': false,
        'error': isTagalog
            ? 'Error sa booking: $e'
            : 'Booking error: $e',
        'errorType': 'general_error',
      };
    }
  }

  static void _validateBookingDetails(Map<String, dynamic> details) {
    if (details.isEmpty) {
      throw FormatException('Booking details cannot be empty');
    }

    final fields = details['fields'] as Map?;
    if (fields == null || fields.isEmpty) {
      throw FormatException('Booking fields are required');
    }
  }

  static String _extractDate(Map<String, dynamic> details) {
    final fields = details['fields'] as Map? ?? {};
    return fields['Date']?.toString() ?? '';
  }

  static String _extractTime(Map<String, dynamic> details) {
    final fields = details['fields'] as Map? ?? {};
    return fields['Time']?.toString() ?? '';
  }
}

// Usage:
final result = await SafeBookingSubmit.submitWithErrorHandling(
  sacramentType: 'Baptism',
  bookingDetails: formData,
  context: context,
  isTagalog: true,
);

if (result['success']) {
  // Show success
  showSuccessDialog(result['message']);
} else {
  // Show error with appropriate message
  showErrorDialog(result['error'], result['errorType']);
}
```

## Admin Features

### Example 8: Admin Conflict Report

```dart
class AdminConflictReport extends StatefulWidget {
  @override
  State<AdminConflictReport> createState() => _AdminConflictReportState();
}

class _AdminConflictReportState extends State<AdminConflictReport> {
  final dateRangeController = TextEditingController();
  List<BookingRecord> conflictingBookings = [];
  bool isLoading = false;

  Future<void> _generateReport(DateTime startDate, DateTime endDate) async {
    setState(() => isLoading = true);

    try {
      // Query all bookings in date range
      final bookings = await SchedulingConflictService.instance
          .getBookingsForDateRange(
        _formatDate(startDate),
        _formatDate(endDate),
      );

      // Find conflicts by grouping by date/time
      final conflicts = <String, List<BookingRecord>>{};
      for (final booking in bookings) {
        if (booking.status == 'confirmed' || booking.status == 'paid') {
          final key = '${booking.date}_${booking.time}';
          if (conflicts[key] == null) {
            conflicts[key] = [];
          }
          conflicts[key]!.add(booking);
        }
      }

      // Extract only groups with multiple bookings
      final conflicting = <BookingRecord>[];
      for (final group in conflicts.values) {
        if (group.length > 1) {
          conflicting.addAll(group);
        }
      }

      setState(() {
        conflictingBookings = conflicting;
        isLoading = false;
      });
    } catch (e) {
      print('Error generating report: $e');
      setState(() => isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Scheduling Conflict Report'),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Date Range',
                  hintText: 'Select dates',
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _generateReport(
                DateTime.now().subtract(Duration(days: 30)),
                DateTime.now(),
              ),
              child: Text('Generate Report'),
            ),
          ],
        ),
        SizedBox(height: 16),
        if (isLoading)
          CircularProgressIndicator()
        else if (conflictingBookings.isEmpty)
          Text('No conflicts found')
        else
          Column(
            children: [
              Text(
                'Found ${conflictingBookings.length} bookings with conflicts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                itemCount: conflictingBookings.length,
                itemBuilder: (context, index) {
                  final booking = conflictingBookings[index];
                  return ListTile(
                    title: Text('${booking.sacramentType} - ${booking.date} ${booking.time}'),
                    subtitle: Text('User: ${booking.userName}'),
                    trailing: Icon(Icons.warning, color: Colors.red),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}
```

## Advanced Scenarios

### Example 9: Batch Conflict Checking

```dart
// Check multiple bookings for conflicts at once
Future<void> checkMultipleBookingsForConflicts() async {
  final bookingsToCheck = [
    {
      'sacramentType': 'Baptism',
      'date': '2026-06-15',
      'time': '10:00 AM',
    },
    {
      'sacramentType': 'Wedding',
      'date': '2026-06-20',
      'time': '2:00 PM',
    },
    {
      'sacramentType': 'Funeral',
      'date': '2026-06-22',
      'time': '9:00 AM',
    },
  ];

  final results = await SchedulingConflictService.instance.checkBatchConflicts(
    bookingsToCheck,
  );

  for (int i = 0; i < results.length; i++) {
    print('Booking ${i + 1}: ${results[i].hasConflict ? "CONFLICT" : "OK"}');
  }
}
```

---

**For more examples and API documentation, see:**
- `SCHEDULING_CONFLICT_DOCUMENTATION.md`
- `SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md`
