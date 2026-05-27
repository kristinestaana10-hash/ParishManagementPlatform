# Sto. Rosario Parish Church - API Contract

## Overview
This document defines the shared API contract for mobile and web platforms, ensuring consistent data structures across all endpoints.

## Base Structure
All documents follow the structured ID format: `{prefix}_{number}` (e.g., `user_001`, `donation_001`, `booking_001`)

---

## Users Collection

### Document ID
- **Format**: `user_001`, `user_002`, etc.
- **Generated**: Auto-incremented via counters collection

### Fields
```typescript
interface User {
  // Identification
  structuredId: string;      // "user_001" - Primary document ID
  uid: string;              // Firebase Auth UID - For authentication
  
  // Profile Information
  name: string;             // Display name
  email: string;            // Email address
  phone?: string;           // Phone number (Philippine format)
  address?: string;         // Physical address
  profileImage?: string;    // Profile image URL
  
  // System Fields
  role: string;             // "parishioner", "admin", etc.
  status: string;           // "active", "inactive"
  
  // Timestamps
  createdAt: Timestamp;
  lastLogin: Timestamp;
  lastUpdated?: Timestamp;
  lastNameChange?: Timestamp; // For 30-day change restriction
}
```

### Alias-Compatibility
- **userName**: Computed from `name` field
- **userEmail**: Computed from `email` field
- Both aliases used in donations/bookings for backward compatibility

---

## Donations Collection

### Document ID
- **Format**: `donation_001`, `donation_002`, etc.
- **Generated**: Auto-incremented via counters collection

### Fields
```typescript
interface Donation {
  // Identification
  structuredId: string;      // "donation_001" - Primary document ID
  
  // User Information (Alias-Compatible)
  userId: string;           // Firebase Auth UID
  userName: string;         // Donor name (alias for name)
  userEmail: string;        // Donor email (alias for email)
  
  // Donation Details
  donationType: string;     // "monetary", "non-monetary"
  isAnonymous: boolean;     // Anonymous donation flag
  amount: number;           // Donation amount
  currency: string;         // "PHP"
  paymentMethod: string;    // "xendit", "cash", "bank"
  
  // Donor Information (for non-anonymous)
  name: string;             // Actual donor name
  email: string;            // Actual donor email
  phone?: string;           // Donor phone
  
  // Additional Fields
  items?: string;           // Non-monetary items
  description?: string;     // Description
  message?: string;         // Donor message
  
  // System Fields
  submittedAt: Timestamp;
  status: string;           // "pending", "confirmed", "completed"
  
  // Xendit Integration (if applicable)
  xendit?: {
    invoiceId: string;
    paymentUrl: string;
    expiryDate: Timestamp;
  };
}
```

---

## Bookings Collection

### Document ID
- **Format**: `booking_001`, `booking_002`, etc.
- **Generated**: Auto-incremented via counters collection

### Fields
```typescript
interface Booking {
  // Identification
  structuredId: string;      // "booking_001" - Primary document ID
  
  // User Information (Alias-Compatible)
  userId: string;           // Firebase Auth UID
  userName: string;         // User name (alias for name)
  userEmail: string;        // User email (alias for email)
  
  // Sacrament Details
  sacramentType: string;    // "Baptism", "Confirmation", etc.
  sacramentTypeKey: string; // "baptism", "confirmation", etc.
  date: string;             // "YYYY-MM-DD"
  time?: string;            // "HH:MM AM/PM"
  
  // Dynamic Form Data
  details: {
    fields: Record<string, any>;  // Form field responses
  };
  
  // System Fields
  submittedAt: Timestamp;
  updatedAt: Timestamp;
  status: string;           // "pending", "confirmed", "cancelled", "rejected"
  assignedPriest: string;   // Priest name/ID
  adminNotes: string;       // Admin notes
  
  // Payment (if applicable)
  payment?: {
    amount: number;
    status: string;
    method: string;
    externalId: string;
  };
}
```

---

## Booking Forms Collection

### Collection
`booking_forms`

### Document ID
Canonical form key, for example:
`baptism`, `confirmation`, `wedding`, `funeral`, `house_blessing`, `anointing`, `mass_intention`, `first_communion`

### Purpose
Stores booking form content that was previously hardcoded in the app. The booking logic, validation, and submission flow continue to use the existing modules; this collection only supplies editable content.

### Fields
```typescript
interface BookingForm {
  formKey: string;
  sacramentTypeKey: string;
  formName: string;
  displayNames: {
    english: string;
    tagalog: string;
  };
  descriptions: {
    english: string;
    tagalog: string;
  };
  fields: string[];
  requirements: string[];
  fees: Record<string, number | string>;
  schedules: Record<string, any>;
  reminders?: {
    english: string[];
    tagalog: string[];
  };
  active: boolean;
  updatedAt: Timestamp;
}
```

---

## Counters Collection

### Document ID
- **Format**: `{prefix}` (e.g., "user", "donation", "booking")

### Fields
```typescript
interface Counter {
  count: number;            // Current count
  prefix: string;           // Counter prefix
  createdAt: Timestamp;
}
```

---

## Auth Endpoints

### User Creation Flow
1. Firebase Auth creates user with UID
2. Client calls `ensureUserRecord()` 
3. System generates structured ID (`user_001`)
4. Document created with both `uid` and `structuredId`

### Profile Updates
- Query by `uid` field, not document ID
- Updates preserve both `uid` and `structuredId`
- Name changes tracked with `lastNameChange` timestamp

---

## Web Compatibility

### Email Lookup
All collections support email-based lookups for web users:
```javascript
// Donations
.where('userEmail', '==', email)
.orWhere('email', '==', email)

// Bookings  
.where('userEmail', '==', email)

// Users
.where('email', '==', email)
```

### Mobile Auth
Mobile users use Firebase Auth UID:
```javascript
// All collections
.where('userId', '==', uid)
```

---

## Data Validation Rules

### Phone Numbers
- Format: `09XXXXXXXXX` or `+639XXXXXXXXX`
- Validated on both client and server

### Email Addresses
- Standard email format validation
- Used for user identification on web

### Name Changes
- 30-day restriction enforced
- Tracked via `lastNameChange` timestamp

---

## Migration Notes

### Existing Data
- Old documents with Firebase Auth UID as document ID remain functional
- New documents use structured IDs
- Both formats supported via Firestore rules

### Backward Compatibility
- `userName` and `userEmail` aliases maintained in donations/bookings
- Email-based queries work for web users
- UID-based queries work for mobile users

---

## Security Rules

### Users Collection
```javascript
match /users/{userId} {
  allow create, read, update: if isSignedIn() && (
    request.auth.uid == userId ||           // Old format
    resource.data.uid == request.auth.uid   // New format
  );
}
```

### Counters Collection
```javascript
match /counters/{counterId} {
  allow read, write: if isSignedIn();
}
```

---

## Field Normalization System

### Overview
The backend accepts both canonical fields and common aliases to ensure compatibility across different client implementations.

### User Field Aliases
```javascript
// Canonical → Aliases
name ← displayName, fullname
email ← emailAddress
phone ← phoneNumber, contact
profileImage ← avatar, photo
```

### Donation Field Aliases
```javascript
// Canonical → Aliases
name ← donorName (also populates userName)
email ← donorEmail (also populates userEmail)
amount ← amountPaid, totalAmount
paymentMethod ← paymentType
```

### Booking Field Aliases
```javascript
// Canonical → Aliases
userName ← bookerName
userEmail ← bookerEmail
sacramentType ← type, sacrament
date ← bookingDate, scheduleDate
time ← bookingTime
```

### Validation Process
1. **Normalization**: Convert all alias fields to canonical format
2. **Validation**: Check required canonical fields
3. **Processing**: Use normalized data throughout the function
4. **Storage**: Save only canonical fields to database

### Example Request
```javascript
// Both formats are accepted:
{
  "donorName": "Juan Dela Cruz",     // Alias → name
  "donorEmail": "juan@email.com",   // Alias → email
  "amountPaid": 1000,               // Alias → amount
  "paymentType": "cash"             // Alias → paymentMethod
}

// Automatically normalized to:
{
  "name": "Juan Dela Cruz",
  "email": "juan@email.com", 
  "amount": 1000,
  "paymentMethod": "cash",
  "userName": "Juan Dela Cruz",     // Auto-populated
  "userEmail": "juan@email.com"     // Auto-populated
}
```

## Implementation Notes

### Structured ID Generation
- Uses Firestore transactions for atomicity
- Falls back to timestamp if counter fails
- Pads with leading zeros (3 digits minimum)

### Cross-Platform Consistency
- Same field names across mobile and web
- Alias fields for backward compatibility
- Consistent timestamp formats
- Unified validation rules
- Field normalization ensures API consistency
