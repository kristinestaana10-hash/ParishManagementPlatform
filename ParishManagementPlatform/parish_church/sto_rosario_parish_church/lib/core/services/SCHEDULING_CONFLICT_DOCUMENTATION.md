# Scheduling Conflict Detection System

## Overview

The Scheduling Conflict Detection System is a comprehensive validation framework that prevents scheduling conflicts between sacrament and service bookings in the parish management platform. It ensures that multiple bookings don't occupy the same date and time slot for restricted service types.

## Architecture

### Core Components

1. **SchedulingConflictModel** (`lib/core/models/scheduling_conflict_model.dart`)
   - `SchedulingConflictResult`: Result object containing conflict information
   - `BookingRecord`: Represents a booking for conflict checking
   - `RestrictedServiceType`: Enum defining services that cannot overlap
   - `TimeSlot`: Represents date/time for conflict detection

2. **SchedulingConflictService** (`lib/core/services/scheduling_conflict_service.dart`)
   - Core service handling all conflict detection logic
   - Checks conflicts against Firebase Firestore data
   - Validates Mass Intention schedules
   - Provides availability checking

3. **FirebaseService Updates** (`lib/core/services/firebase_service.dart`)
   - `submitBooking()`: Updated to check conflicts before submission
   - `checkBookingConflict()`: Pre-submission conflict validation
   - `validateMassIntentionSchedule()`: Mass schedule validation
   - `getAvailableTimeSlots()`: Get available booking times

## Conflict Validation Rules

### Restricted Service Types

The following services **CANNOT** have overlapping bookings on the same date and time:

- **Baptism** (Binyag)
- **Confirmation** (Kumpil)
- **Wedding** (Kasal)
- **Funeral Mass** (Misa para sa Yumao)
- **First Communion** (Unang Komunyon)
- **House Blessing** (Basbas ng Bahay)
- **Anointing of the Sick** (Pagpapahid sa May Sakit)

### Mass Intention Exception

**Mass Intention** (Intensyon ng Misa) bookings are **ALLOWED** to have multiple bookings on the same date and time:

- Multiple users can book the same Mass schedule for different intentions
- Each Mass Intention booking must validate against the official Mass Schedule table
- Invalid or non-existing Mass schedules are prevented

## Conflict Detection Logic

### Detection Algorithm

```
1. Extract date and time from booking request
2. Normalize sacrament type to canonical form
3. Check service type:
   - If Mass Intention: Validate against Mass Schedule table (allow multiple)
   - If Restricted Service: Check against all approved bookings
   - Otherwise: Allow booking (no conflict possible)
4. Query Firestore for approved bookings:
   - Status: 'confirmed' or 'paid'
   - Date: Must match requested date
   - Time: Must match requested time
5. If any approved booking found: Return conflict
6. Otherwise: Allow booking
```

### Conflict Resolution

When a conflict is detected:

1. **Booking is Rejected** - Not saved to Firestore
2. **Error Message Displayed** to user with details:
   - "This schedule is already occupied."
   - "The selected date and time conflicts with another approved booking."
   - "Please choose another available schedule."
3. **User can:**
   - Select a different date/time
   - Choose a different service type
   - Contact administrator

## Implementation Details

### Booking Status States

Only bookings with these statuses are checked for conflicts:
- `confirmed` - Approved by admin
- `paid` - Payment completed

Bookings NOT checked:
- `pending` - Awaiting admin approval
- `cancelled` - User cancelled
- `rejected` - Admin rejected

### Date/Time Format

- **Date Format**: `YYYY-MM-DD` (ISO 8601)
- **Time Format**: `HH:MM AM/PM` or `HH:MM` (24-hour)
- **Time Matching**: Case-insensitive exact match for slot detection

### Mass Schedule Validation

Mass Intention bookings must:

1. Have BOTH date and time specified
2. Match an entry in the `massSchedules` Firestore collection
3. Collection structure:
   ```
   /massSchedules/{id}
   - date: string (YYYY-MM-DD)
   - time: string (HH:MM)
   - description: string
   - ...
   ```

## API Usage

### Check Booking Conflict

```dart
final conflictService = SchedulingConflictService.instance;

final result = await conflictService.checkSchedulingConflict(
  sacramentType: 'Baptism',
  date: '2026-05-31',
  time: '10:00 AM',
);

if (result.hasConflict) {
  print('Conflict: ${result.errorMessage}');
  print('Conflicting booking: ${result.conflictingBookingId}');
} else {
  print('No conflict detected');
}
```

### Validate Mass Intention Schedule

```dart
final isValid = await conflictService.validateMassIntentionSchedule(
  date: '2026-05-31',
  time: '6:00 AM',
);

if (!isValid) {
  print('Invalid Mass schedule');
}
```

### Get Available Time Slots

```dart
final availableSlots = await conflictService.getAvailableTimeSlots(
  '2026-05-31',
  ['6:00 AM', '8:00 AM', '10:00 AM', '12:00 PM'],
);

// Returns non-booked time slots
```

### Submit Booking (Integrated Validation)

```dart
try {
  await FirebaseService.instance.submitBooking(
    sacramentType: 'Wedding',
    details: {
      'fields': {
        'Date': '2026-06-15',
        'Time': '2:00 PM',
      }
    },
    checkConflict: true, // Enable conflict checking (default)
  );
} on Exception catch (e) {
  // Error message includes conflict details if applicable
  if (e.toString().contains('schedule is already occupied')) {
    // Handle scheduling conflict
  }
}
```

## Cloud Functions Integration

Validation is also performed in Cloud Functions for server-side security:

- `createXenditBookingInvoice()`: Checks conflicts before invoice creation
- `updateBookingStatus()`: Validates status transitions
- Field normalization handles aliases (bookingDate, scheduleDate, etc.)

## Error Messages

### English

- "This schedule is already occupied."
- "The selected date and time conflicts with another approved booking."
- "Please choose another available schedule."
- "The selected date and time does not match any official Mass schedule."
- "Mass Intention requires both date and time to be specified."

### Tagalog

- "Ang schedule na ito ay nasa kung taon na."
- "Ang piniling araw at oras ay may kugamit sa ibang aprubadong booking."
- "Pumili ng ibang available na schedule."
- "Ang piniling araw at oras ay hindi tumutugma sa anumang opisyal na schedule ng Misa."
- "Ang Mass Intention ay nangangailangan ng parehong araw at oras na dapat tukuyin."

## Testing Scenarios

### Scenario 1: Prevent Overlapping Wedding Bookings

```
Existing Booking:
- Service: Wedding
- Date: 2026-06-15
- Time: 2:00 PM
- Status: confirmed

New Request:
- Service: Baptism
- Date: 2026-06-15
- Time: 2:00 PM

Result: CONFLICT DETECTED
Reason: Different services, same date/time → Not allowed
```

### Scenario 2: Allow Multiple Mass Intentions

```
Existing Booking:
- Service: Mass Intention
- Date: 2026-05-31
- Time: 6:00 AM
- Status: confirmed

New Request:
- Service: Mass Intention
- Date: 2026-05-31
- Time: 6:00 AM

Result: NO CONFLICT
Reason: Mass Intention allows multiple bookings at same time
```

### Scenario 3: Allow Different Times on Same Date

```
Existing Booking:
- Service: Baptism
- Date: 2026-06-15
- Time: 2:00 PM
- Status: confirmed

New Request:
- Service: Baptism
- Date: 2026-06-15
- Time: 4:00 PM

Result: NO CONFLICT
Reason: Different times → Not overlapping
```

### Scenario 4: Pending Bookings Don't Block New Bookings

```
Existing Booking:
- Service: Wedding
- Date: 2026-06-15
- Time: 2:00 PM
- Status: pending (awaiting admin approval)

New Request:
- Service: Baptism
- Date: 2026-06-15
- Time: 2:00 PM

Result: NO CONFLICT
Reason: Pending bookings are not checked (only confirmed/paid)
```

## Future Enhancements

1. **Time Duration Calculation**: Extend overlap detection to consider service duration
   - Baptism: 30 minutes
   - Wedding: 60 minutes
   - etc.

2. **Venue-Based Conflicts**: When multiple venues are supported
   - Same venue requirement for conflicts

3. **Priest Availability**: Prevent priest double-booking
   - Link bookings to assigned priests

4. **Notification System**: Alert admins of conflicts
   - Automatic emails/SMS

5. **Availability Calendar**: UI component showing booked slots
   - Interactive date/time picker with availability

6. **Bulk Conflict Check**: Admin dashboard for conflict reports
   - Date range analysis
   - Service type breakdown

## Database Schema

### Bookings Collection

```typescript
/bookings/{bookingId}
{
  structuredId: "booking_001",
  userId: "auth-uid",
  userName: "John Doe",
  userEmail: "john@example.com",
  sacramentType: "Wedding",
  sacramentTypeKey: "wedding",
  date: "2026-06-15",
  time: "2:00 PM",
  status: "confirmed", // pending|confirmed|paid|cancelled|rejected
  details: {
    fields: {...}
  },
  submittedAt: Timestamp,
  updatedAt: Timestamp,
  assignedPriest: "Rev. Father Name",
  adminNotes: "..."
}
```

### Mass Schedules Collection

```typescript
/massSchedules/{scheduleId}
{
  date: "2026-05-31",
  time: "6:00 AM",
  description: "Sunday Mass",
  isActive: true,
  capacity: 100,
  ...
}
```

## Support

For issues or questions about the scheduling conflict system:
1. Check error messages for specific conflict details
2. Verify date/time format compliance
3. Review this documentation
4. Contact system administrator

---

**Version**: 1.0
**Last Updated**: May 24, 2026
**Status**: Production Ready
