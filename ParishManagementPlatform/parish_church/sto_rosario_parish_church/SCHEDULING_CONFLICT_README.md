# Scheduling Conflict Detection System - README

## Overview

This is a complete scheduling conflict detection system for the Sto. Rosario Parish Church Management Platform. It automatically prevents booking conflicts between sacrament and service bookings.

## Quick Links

- **[Implementation Summary](./SCHEDULING_CONFLICT_IMPLEMENTATION_SUMMARY.md)** - Complete overview of what was implemented
- **[Integration Guide](./SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md)** - How to use and test the system
- **[Usage Examples](./SCHEDULING_CONFLICT_USAGE_EXAMPLES.md)** - Code examples and integration patterns
- **[Technical Documentation](./lib/core/services/SCHEDULING_CONFLICT_DOCUMENTATION.md)** - Deep technical details

## Features

✅ **Automatic Conflict Detection**
- Checks all existing approved bookings
- Prevents overlapping bookings for restricted services
- Real-time validation before submission

✅ **Mass Intention Exception**
- Allows multiple bookings at same date/time
- Validates against official Mass schedules
- Prevents invalid Mass schedule bookings

✅ **Restricted Services**
- Baptism
- Confirmation  
- Wedding
- Funeral Mass
- First Communion
- House Blessing
- Anointing of the Sick

✅ **Multi-Layer Validation**
- Client-side detection (Flutter)
- Server-side security (Cloud Functions)
- Comprehensive error messages (English & Tagalog)

✅ **User-Friendly**
- Clear error messages
- Helpful suggestions
- Easy rescheduling

## Architecture

### Components

```
lib/core/models/
├── scheduling_conflict_model.dart
    ├── SchedulingConflictResult
    ├── BookingRecord
    ├── RestrictedServiceType
    └── TimeSlot

lib/core/services/
├── scheduling_conflict_service.dart
│   └── SchedulingConflictService (Main service)
├── firebase_service.dart (Updated)
│   ├── submitBooking() - Enhanced with conflict checking
│   ├── checkBookingConflict()
│   ├── validateMassIntentionSchedule()
│   ├── getAvailableTimeSlots()
│   └── getBookingsForDate()
└── SCHEDULING_CONFLICT_DOCUMENTATION.md

functions/
└── index.js (Updated)
    ├── checkSchedulingConflict() - Server-side validation
    ├── validateMassIntentionSchedule() - Mass schedule validation
    ├── isRestrictedService()
    └── isMassIntention()
```

## How It Works

### User Booking Flow

```
User submits booking form
        ↓
Extract date, time, and service type
        ↓
SchedulingConflictService.checkSchedulingConflict()
        ↓
Query Firestore for approved bookings (status: confirmed|paid)
        ↓
Check for date/time overlap
        ↓
If conflict found:
    - Block booking
    - Show error message
    - User selects different time
Else if Mass Intention:
    - Validate against massSchedules table
    - If invalid: Show error, block booking
    - If valid: Proceed to submission
Else:
    - Submit booking to Firestore
    - Cloud Functions validates again
    - Invoice created and sent to user
```

## Getting Started

### 1. Understanding the System

Read the [Integration Guide](./SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md) for:
- System overview
- How conflict detection works
- Error messages
- Testing scenarios

### 2. Testing

Follow the test cases in [Integration Guide](./SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md#testing-the-system):
- Test Case 1: Prevent overlapping bookings
- Test Case 2: Allow different service same date
- Test Case 3: Allow multiple Mass Intentions
- Test Case 4: Reject invalid Mass schedules
- Test Case 5: Pending bookings don't block

### 3. Using in Your Code

See [Usage Examples](./SCHEDULING_CONFLICT_USAGE_EXAMPLES.md) for:
- Basic usage
- Form integration
- Real-time availability
- Error handling
- Admin features

## API Quick Reference

### SchedulingConflictService

```dart
// Check for conflicts
final result = await SchedulingConflictService.instance.checkSchedulingConflict(
  sacramentType: 'Baptism',
  date: '2026-06-15',
  time: '10:00 AM',
);

// Validate Mass schedule
final isValid = await SchedulingConflictService.instance
    .validateMassIntentionSchedule(
  date: '2026-05-31',
  time: '6:00 AM',
);

// Get available slots
final available = await SchedulingConflictService.instance
    .getAvailableTimeSlots(
  '2026-06-15',
  ['9:00 AM', '10:00 AM', '2:00 PM'],
);
```

### FirebaseService

```dart
// Submit with automatic conflict checking
await FirebaseService.instance.submitBooking(
  sacramentType: 'Baptism',
  details: {'fields': {...}},
  checkConflict: true, // Default
);

// Pre-check conflicts
final result = await FirebaseService.instance.checkBookingConflict(
  sacramentType: 'Baptism',
  details: {...},
);
```

## Error Messages

### Conflict Detected

**English:**
> "This schedule is already occupied. The selected date and time conflicts with another approved booking. Please choose another available schedule."

**Tagalog:**
> "Ang schedule na ito ay nasa kung taon na. Ang piniling araw at oras ay may kugamit sa ibang aprubadong booking. Pumili ng ibang available na schedule."

### Invalid Mass Schedule

**English:**
> "The selected date and time does not match any official Mass schedule. Please select a valid Mass schedule."

**Tagalog:**
> "Ang piniling araw at oras ay hindi tumutugma sa anumang opisyal na schedule ng Misa. Pumili ng valid na Mass schedule."

## Database Setup

### Firestore Collections

**Bookings Collection** (`/bookings/{bookingId}`)
```json
{
  "structuredId": "booking_001",
  "userId": "auth-uid",
  "userName": "John Doe",
  "sacramentType": "Wedding",
  "date": "2026-06-15",
  "time": "2:00 PM",
  "status": "confirmed",
  "details": {...}
}
```

**Mass Schedules Collection** (`/massSchedules/{scheduleId}`)
```json
{
  "date": "2026-05-31",
  "time": "6:00 AM",
  "description": "Sunday Mass",
  "isActive": true,
  "capacity": 100
}
```

## Files in This System

### Dart/Flutter Code
- `lib/core/models/scheduling_conflict_model.dart` (382 lines)
- `lib/core/services/scheduling_conflict_service.dart` (351 lines)
- `lib/core/services/firebase_service.dart` (Updated)

### Cloud Functions
- `functions/index.js` (Updated with 100+ lines)

### Documentation
- `SCHEDULING_CONFLICT_IMPLEMENTATION_SUMMARY.md` - This system overview
- `SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md` - Integration & testing guide
- `SCHEDULING_CONFLICT_USAGE_EXAMPLES.md` - Code examples
- `lib/core/services/SCHEDULING_CONFLICT_DOCUMENTATION.md` - Technical reference

## Key Features

### Conflict Prevention
- Automatic detection before booking submission
- Server-side validation for security
- Prevents double-booking of restricted services

### Mass Intention Support
- Allows multiple bookings at same time
- Validates against official Mass schedules
- Prevents invalid schedule selection

### User Experience
- Clear error messages
- Helpful suggestions
- Easy date/time selection
- Real-time availability checking

### Admin Capabilities
- View all scheduled bookings
- Generate conflict reports
- Check availability for date ranges
- Monitor booking statuses

## Configuration

### Add New Restricted Service

Edit `lib/core/services/scheduling_conflict_service.dart`:

```dart
static const List<String> restrictedServiceKeys = [
  'baptism',
  'confirmation',
  'wedding',
  'funeral',
  'first_communion',
  'house_blessing',
  'anointing',
  'new_service', // Add here
];
```

### Change Error Messages

Edit error messages in `submitBooking()` method or Cloud Functions.

### Adjust Time Validation

Modify `TimeSlot.doSlotsOverlap()` method to change time matching logic.

## Troubleshooting

### Conflict showing but shouldn't exist
- Check booking status (must be `confirmed` or `paid`)
- Verify date/time format (YYYY-MM-DD and HH:MM)
- Check service type normalization

### Mass schedule validation failing
- Verify `massSchedules` collection exists
- Check schedule entries for the date
- Ensure time format matches (case-insensitive)

### No conflicts showing when they should
- Verify bookings have status `confirmed` or `paid`
- Check Firestore console for actual data
- Review console logs for validation details

See [Integration Guide Troubleshooting](./SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md#troubleshooting) for more.

## Testing

Complete test scenarios included in [Integration Guide](./SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md#testing-scenarios).

Quick test:
1. Create test booking on 2026-06-15 at 2:00 PM (status: confirmed)
2. Try to book same date/time → Should fail
3. Try to book same date/different time → Should succeed
4. Book Mass Intention same date/time → Should succeed

## Performance

- ✅ Indexed Firestore queries
- ✅ Efficient filtering and sorting
- ✅ Server-side caching via Cloud Functions
- ✅ Graceful error handling (fail-open)

## Support

For questions or issues:

1. **Read the documentation:**
   - [Integration Guide](./SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md)
   - [Usage Examples](./SCHEDULING_CONFLICT_USAGE_EXAMPLES.md)
   - [Technical Docs](./lib/core/services/SCHEDULING_CONFLICT_DOCUMENTATION.md)

2. **Check the code:**
   - Model definitions in `scheduling_conflict_model.dart`
   - Service implementation in `scheduling_conflict_service.dart`
   - Cloud Functions in `functions/index.js`

3. **Test scenarios:**
   - See Integration Guide for detailed test cases
   - Use provided test data setup

## Status

✅ **Implementation Complete**

- Client-side: ✅ Fully implemented
- Server-side: ✅ Fully implemented
- Documentation: ✅ Comprehensive
- Testing: ✅ Test scenarios provided
- Production Ready: ✅ Yes

**Version:** 1.0  
**Date:** May 24, 2026  
**Status:** Production Ready

---

## Quick Navigation

- [Implementation Summary](./SCHEDULING_CONFLICT_IMPLEMENTATION_SUMMARY.md) - Overview of what was built
- [Integration Guide](./SCHEDULING_CONFLICT_INTEGRATION_GUIDE.md) - How to test and use
- [Usage Examples](./SCHEDULING_CONFLICT_USAGE_EXAMPLES.md) - Code examples
- [Technical Documentation](./lib/core/services/SCHEDULING_CONFLICT_DOCUMENTATION.md) - Deep dive
