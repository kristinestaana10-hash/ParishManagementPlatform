# Scheduling Conflict Detection System - Integration Guide

## Quick Start

The scheduling conflict detection system is now fully integrated into the Parish Management Platform. No additional configuration is required—the system works automatically when users submit booking requests.

## How It Works

### User Booking Flow

```
1. User fills out sacrament booking form
   ↓
2. User clicks "Submit Booking"
   ↓
3. Form extracts date, time, and sacrament type
   ↓
4. SchedulingConflictService checks Firestore for conflicts
   ↓
5a. If conflict found:
    - Booking rejected
    - Error message displayed to user
    - User can select different date/time
   ↓
5b. If no conflict found:
    - Booking submitted to Firestore
    - Success message displayed
    - User proceeds to payment (if needed)
```

### Conflict Checking Layers

1. **Client-Side (Dart/Flutter)**
   - Real-time conflict checking in FirebaseService
   - Immediate user feedback
   - Optional pre-submission validation

2. **Server-Side (Cloud Functions)**
   - Final validation before payment invoice creation
   - Security check against manipulated requests
   - Transaction safety

## Implementation Status

### ✅ Completed Components

#### 1. Core Models (`lib/core/models/scheduling_conflict_model.dart`)
- `SchedulingConflictResult`: Conflict information
- `BookingRecord`: Booking data representation
- `RestrictedServiceType`: Service restriction enum
- `TimeSlot`: Date/time validation

#### 2. Scheduling Conflict Service (`lib/core/services/scheduling_conflict_service.dart`)
- Comprehensive conflict detection
- Mass Intention schedule validation
- Availability checking utilities
- Batch conflict checking

#### 3. Firebase Service Updates (`lib/core/services/firebase_service.dart`)
- `submitBooking()`: Integrated conflict checking
- `checkBookingConflict()`: Pre-submission validation
- `validateMassIntentionSchedule()`: Mass schedule validation
- `getAvailableTimeSlots()`: Availability API
- `getBookingsForDate()`: Date-specific bookings

#### 4. Cloud Functions Validation (`functions/index.js`)
- `checkSchedulingConflict()`: Server-side conflict detection
- `validateMassIntentionSchedule()`: Server-side Mass schedule validation
- Integrated into `createXenditBookingInvoice()` function

#### 5. Documentation
- Comprehensive feature documentation
- API usage examples
- Testing scenarios
- Database schema reference

## Error Messages

The system automatically displays error messages to users when conflicts occur:

### English Error Messages
```
"This schedule is already occupied."
"The selected date and time conflicts with another approved booking."
"Please choose another available schedule."
"The selected date and time does not match any official Mass schedule. Please select a valid Mass schedule."
"Mass Intention requires both date and time to be specified."
```

### Tagalog Error Messages
```
"Ang schedule na ito ay nasa kung taon na."
"Ang piniling araw at oras ay may kugamit sa ibang aprubadong booking."
"Pumili ng ibang available na schedule."
"Ang piniling araw at oras ay hindi tumutugma sa anumang opisyal na schedule ng Misa."
"Ang Mass Intention ay nangangailangan ng parehong araw at oras na dapat tukuyin."
```

## Testing the System

### Setup: Create Test Data

Before testing, you need to set up test bookings in Firestore:

```
Collection: /bookings
Document: booking_001
{
  "structuredId": "booking_001",
  "userId": "test-user-1",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "sacramentType": "Wedding",
  "sacramentTypeKey": "wedding",
  "date": "2026-06-15",
  "time": "2:00 PM",
  "status": "confirmed",
  "details": {...},
  "submittedAt": Timestamp,
  "updatedAt": Timestamp
}
```

For Mass Intention testing, create Mass schedules:

```
Collection: /massSchedules
Document: mass_001
{
  "date": "2026-05-31",
  "time": "6:00 AM",
  "description": "Sunday Mass",
  "isActive": true,
  "capacity": 100
}
```

### Test Case 1: Prevent Overlapping Bookings

**Setup:**
- Existing: Wedding on 2026-06-15 at 2:00 PM (confirmed)

**Test:**
1. Open sacrament booking form
2. Select "Baptism" as service type
3. Enter date: 2026-06-15
4. Enter time: 2:00 PM
5. Submit form

**Expected Result:**
- ❌ Booking rejected
- Error displayed: "This schedule is already occupied. The selected date and time conflicts with another approved booking. Please choose another available schedule."

**Try Next:**
- Change time to 4:00 PM
- ✅ Booking should succeed (different time)

### Test Case 2: Allow Different Service Same Date

**Setup:**
- Existing: Wedding on 2026-06-15 at 2:00 PM (confirmed)

**Test:**
1. Open sacrament booking form
2. Select "Baptism" as service type
3. Enter date: 2026-06-15
4. Enter time: 4:00 PM (different time)
5. Submit form

**Expected Result:**
- ✅ Booking succeeds
- Message: "Booking submitted! Please wait for admin approval before proceeding to payment."

### Test Case 3: Allow Multiple Mass Intentions

**Setup:**
- Existing: Mass Intention on 2026-05-31 at 6:00 AM (confirmed)
- Mass schedule exists for 2026-05-31 at 6:00 AM

**Test:**
1. Open sacrament booking form
2. Select "Mass Intention" as service type
3. Enter date: 2026-05-31
4. Enter time: 6:00 AM
5. Submit form

**Expected Result:**
- ✅ Booking succeeds (Mass Intention allows multiple)
- Message: "Mass Intention submitted! Please wait for admin approval before proceeding to payment."

### Test Case 4: Reject Invalid Mass Schedule

**Setup:**
- No Mass schedule exists for 2026-06-20 at 3:00 PM

**Test:**
1. Open sacrament booking form
2. Select "Mass Intention" as service type
3. Enter date: 2026-06-20
4. Enter time: 3:00 PM (time not in official schedule)
5. Submit form

**Expected Result:**
- ❌ Booking rejected
- Error: "The selected date and time does not match any official Mass schedule. Please select a valid Mass schedule."

### Test Case 5: Pending Bookings Don't Block

**Setup:**
- Existing: Wedding on 2026-06-15 at 2:00 PM (pending - NOT confirmed)

**Test:**
1. Open sacrament booking form
2. Select "Baptism" as service type
3. Enter date: 2026-06-15
4. Enter time: 2:00 PM
5. Submit form

**Expected Result:**
- ✅ Booking succeeds
- Message: "Booking submitted! Please wait for admin approval before proceeding to payment."
- **Reason:** Pending bookings are not locked in yet; only confirmed/paid block conflicts

## Database Preparation

### Create Mass Schedules Collection

```javascript
// Run in Firebase Console or Firestore Rules
// Create sample Mass schedule entries

db.collection('massSchedules').doc('mass_001').set({
  date: '2026-05-31',
  time: '6:00 AM',
  description: 'Sunday Mass',
  isActive: true,
  capacity: 100,
  createdAt: admin.firestore.FieldValue.serverTimestamp()
});

db.collection('massSchedules').doc('mass_002').set({
  date: '2026-05-31',
  time: '8:00 AM',
  description: 'Sunday Mass',
  isActive: true,
  capacity: 100,
  createdAt: admin.firestore.FieldValue.serverTimestamp()
});

// ... add more for daily/weekly schedule
```

## API Reference

### SchedulingConflictService

```dart
// Check for conflicts
final result = await SchedulingConflictService.instance.checkSchedulingConflict(
  sacramentType: 'Baptism',
  date: '2026-06-15',
  time: '10:00 AM',
);

if (result.hasConflict) {
  print('Conflict detected: ${result.conflictingBookingId}');
}

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
  ['9:00 AM', '10:00 AM', '2:00 PM', '4:00 PM'],
);

// Get bookings for date
final bookings = await SchedulingConflictService.instance
    .getBookingsForDate('2026-06-15');
```

### FirebaseService

```dart
// Submit booking (includes conflict checking by default)
await FirebaseService.instance.submitBooking(
  sacramentType: 'Baptism',
  details: {
    'fields': {
      'Date': '2026-06-15',
      'Time': '10:00 AM',
      'Name': 'John Doe',
    }
  },
  checkConflict: true, // Optional, true by default
);

// Pre-check conflicts
final result = await FirebaseService.instance.checkBookingConflict(
  sacramentType: 'Baptism',
  details: {...},
);

// Validate Mass schedule
final isValid = await FirebaseService.instance
    .validateMassIntentionSchedule(
  date: '2026-05-31',
  time: '6:00 AM',
);

// Get available slots
final slots = await FirebaseService.instance.getAvailableTimeSlots(
  date: '2026-06-15',
  allPossibleTimeSlots: ['9:00 AM', '10:00 AM', '2:00 PM'],
);
```

## Troubleshooting

### Issue: "Conflict detected" but no bookings visible

**Cause:** Booking might be in `pending` status (not `confirmed` or `paid`)

**Solution:** 
- Check Firestore console
- Look for bookings with `status: 'confirmed'` or `status: 'paid'`
- Only these statuses are checked for conflicts

### Issue: Mass Intention bookings rejected

**Cause:** Mass schedule not found in `massSchedules` collection

**Solution:**
1. Verify `massSchedules` collection exists
2. Check if entry exists for the requested date/time
3. Ensure date format is `YYYY-MM-DD`
4. Ensure time format matches (case-insensitive)

### Issue: Same time slots allowed on different dates

**This is by design** ✓

- Different dates = no conflict
- Same date + same time = conflict (for restricted services)
- Multiple Mass Intentions same date/time = allowed

## Performance Considerations

### Query Optimization

The system uses indexed Firestore queries:

```javascript
// Indexed queries for performance
db.collection('bookings')
  .where('date', '==', date)
  .where('status', 'in', ['confirmed', 'paid'])
```

### Recommended Firestore Indexes

```yaml
indexes:
  - collection: bookings
    queryScope: COLLECTION
    fields:
      - fieldPath: date
        order: ASCENDING
      - fieldPath: status
        order: ASCENDING
```

## Future Enhancements

1. **Time Duration Calculation**
   - Account for service duration (e.g., Wedding 60 min, Baptism 30 min)
   - Prevent overlaps with partial time ranges

2. **Venue Support**
   - Different venues, different conflict spaces
   - Multi-venue conflict checking

3. **Priest Assignment**
   - Prevent priest double-booking
   - Priest availability calendar

4. **Admin Dashboard**
   - Visual conflict reports
   - Bulk conflict checks
   - Manual override capabilities

5. **Calendar UI**
   - Interactive availability picker
   - Real-time booked slot visualization

6. **Notifications**
   - Email conflicts for admins
   - Auto-reschedule suggestions

## Support & Maintenance

### Monitoring

Check Cloud Function logs for conflict detection:

```
functions: Firebase Function: checkSchedulingConflict
timestamp: 2026-05-24 10:30:00
message: CONFLICT DETECTED with booking booking_001
```

### Common Maintenance Tasks

**View all conflicts in past month:**
```javascript
db.collection('bookings')
  .where('status', '==', 'confirmed')
  .where('date', '>=', '2026-04-24')
  .where('date', '<=', '2026-05-24')
  .get()
```

**Update conflict resolution:**
- Modify `checkSchedulingConflict()` function
- Update error messages in UI
- Test with full scenario

## Documentation Files

- `SCHEDULING_CONFLICT_DOCUMENTATION.md` - Technical details
- `INTEGRATION_GUIDE.md` - This file
- `lib/core/models/scheduling_conflict_model.dart` - Model definitions
- `lib/core/services/scheduling_conflict_service.dart` - Service implementation
- `functions/index.js` - Cloud Functions implementation

---

**Version**: 1.0
**Status**: Production Ready ✅
**Last Updated**: May 24, 2026
**Maintained By**: Parish Management System Team
