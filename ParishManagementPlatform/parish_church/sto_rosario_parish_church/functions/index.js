const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const fetch = require('node-fetch');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

admin.initializeApp();

const XENDIT_SECRET_KEY = defineSecret('XENDIT_SECRET_KEY');
const XENDIT_WEBHOOK_TOKEN = defineSecret('XENDIT_WEBHOOK_TOKEN');
const SMTP_USER = defineSecret('SMTP_USER');
const SMTP_APP_PASSWORD = defineSecret('SMTP_APP_PASSWORD');
const SMTP_FROM_NAME = defineSecret('SMTP_FROM_NAME');
const GROQ_API_KEY = defineSecret('GROQ_API_KEY');
const GROQ_CHAT_MODEL = 'openai/gpt-oss-20b';

function requireNonEmptyString(value, fieldName) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `${fieldName} is required.`);
  }
  return value.trim();
}

function requireBoundedString(value, fieldName, maxLength) {
  const text = requireNonEmptyString(value, fieldName);
  if (text.length > maxLength) {
    throw new HttpsError('invalid-argument', `${fieldName} must be ${maxLength} characters or fewer.`);
  }
  return text;
}

function isValidEmail(email) {
  if (typeof email !== 'string') return false;
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim());
}

function formatPhp(amountNumber) {
  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amountNumber);
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function generateOtpCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function hashOtp({ email, otp, salt }) {
  return crypto
    .createHash('sha256')
    .update(`${normalizeEmail(email)}|${String(otp)}|${String(salt)}`)
    .digest('hex');
}

async function generateStructuredId(db, prefix) {
  try {
    const counterRef = db.collection('counters').doc(prefix);
    
    const result = await db.runTransaction(async (transaction) => {
      const counterDoc = await transaction.get(counterRef);
      
      let currentCount = 0;
      if (counterDoc.exists) {
        currentCount = counterDoc.data().count || 0;
      }
      
      const newCount = currentCount + 1;
      
      if (counterDoc.exists) {
        transaction.update(counterRef, { count: newCount });
      } else {
        transaction.set(counterRef, {
          count: newCount,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          prefix: prefix,
        });
      }
      
      const paddedCount = newCount.toString().padStart(3, '0');
      return `${prefix}_${paddedCount}`;
    });
    
    return result;
  } catch (error) {
    console.error('Error generating structured ID:', error);
    const timestamp = Date.now();
    return `${prefix}_${timestamp}`;
  }
}

// Field normalization for API compatibility
// Accepts both canonical fields and common aliases
function normalizeFields(data, type) {
  const normalized = { ...data };
  
  // User field aliases
  if (type === 'user') {
    // Name aliases
    if (normalized.displayName !== undefined) {
      normalized.name = normalized.displayName;
      delete normalized.displayName;
    }
    if (normalized.fullname !== undefined) {
      normalized.name = normalized.fullname;
      delete normalized.fullname;
    }
    
    // Email aliases
    if (normalized.emailAddress !== undefined) {
      normalized.email = normalized.emailAddress;
      delete normalized.emailAddress;
    }
    
    // Phone aliases
    if (normalized.phoneNumber !== undefined) {
      normalized.phone = normalized.phoneNumber;
      delete normalized.phoneNumber;
    }
    if (normalized.contact !== undefined) {
      normalized.phone = normalized.contact;
      delete normalized.contact;
    }
    
    // Profile image aliases
    if (normalized.avatar !== undefined) {
      normalized.profileImage = normalized.avatar;
      delete normalized.avatar;
    }
    if (normalized.photo !== undefined) {
      normalized.profileImage = normalized.photo;
      delete normalized.photo;
    }
  }
  
  // Donation field aliases
  if (type === 'donation') {
    // User info aliases
    if (normalized.donorName !== undefined) {
      normalized.name = normalized.donorName;
      normalized.userName = normalized.donorName;
      delete normalized.donorName;
    }
    if (normalized.donorEmail !== undefined) {
      normalized.email = normalized.donorEmail;
      normalized.userEmail = normalized.donorEmail;
      delete normalized.donorEmail;
    }
    
    // Amount aliases
    if (normalized.amountPaid !== undefined) {
      normalized.amount = normalized.amountPaid;
      delete normalized.amountPaid;
    }
    if (normalized.totalAmount !== undefined) {
      normalized.amount = normalized.totalAmount;
      delete normalized.totalAmount;
    }
    
    // Payment method aliases
    if (normalized.paymentType !== undefined) {
      normalized.paymentMethod = normalized.paymentType;
      delete normalized.paymentType;
    }
  }
  
  // Booking field aliases
  if (type === 'booking') {
    // User info aliases
    if (normalized.bookerName !== undefined) {
      normalized.userName = normalized.bookerName;
      delete normalized.bookerName;
    }
    if (normalized.bookerEmail !== undefined) {
      normalized.userEmail = normalized.bookerEmail;
      delete normalized.bookerEmail;
    }
    
    // Sacrament type aliases
    if (normalized.type !== undefined) {
      normalized.sacramentType = normalized.type;
      delete normalized.type;
    }
    if (normalized.sacrament !== undefined) {
      normalized.sacramentType = normalized.sacrament;
      delete normalized.sacrament;
    }
    if (normalized.sacramentTypeKey !== undefined && normalized.sacramentType === undefined) {
      normalized.sacramentType = normalized.sacramentTypeKey;
    }
    if (normalized.bookingType !== undefined && normalized.sacramentType === undefined) {
      normalized.sacramentType = normalized.bookingType;
    }
    
    // Date/time aliases
    if (normalized.bookingDate !== undefined) {
      normalized.date = normalized.bookingDate;
      delete normalized.bookingDate;
    }
    if (normalized.scheduleDate !== undefined) {
      normalized.date = normalized.scheduleDate;
      delete normalized.scheduleDate;
    }
    if (normalized.bookingTime !== undefined) {
      normalized.time = normalized.bookingTime;
      delete normalized.bookingTime;
    }
  }
  
  return normalized;
}

// Validate required canonical fields
function validateCanonicalFields(data, type) {
  const errors = [];
  
  if (type === 'user') {
    const hasFullName = data.name && typeof data.name === 'string' && data.name.trim().length > 0;
    const hasSplitName = (
      (data.firstName && typeof data.firstName === 'string' && data.firstName.trim().length > 0) ||
      (data.lastName && typeof data.lastName === 'string' && data.lastName.trim().length > 0)
    );
    if (!hasFullName && !hasSplitName) {
      errors.push('name or firstName/lastName is required and must be a string');
    }
    if (!data.email || typeof data.email !== 'string') {
      errors.push('email is required and must be a string');
    } else if (!isValidEmail(data.email)) {
      errors.push('email must be a valid email address');
    }
  }
  
  if (type === 'donation') {
    // userName is optional for guest donations - will default to 'Anonymous'
    // userEmail is optional for anonymous donations
    if (typeof data.amount !== 'number' || data.amount <= 0) {
      errors.push('amount must be a number greater than 0');
    }
    if (data.donationType === 'massOffering') {
      if (!data.offeringLocation || typeof data.offeringLocation !== 'string') {
        errors.push('offeringLocation is required for mass offerings');
      }
    }
  }
  
  if (type === 'booking') {
    if (!data.userName || typeof data.userName !== 'string') {
      errors.push('userName is required and must be a string');
    }
    if (!data.userEmail || typeof data.userEmail !== 'string') {
      errors.push('userEmail is required and must be a string');
    }
    if (!data.sacramentType || typeof data.sacramentType !== 'string') {
      errors.push('sacramentType is required and must be a string');
    }
  }
  
  return errors;
}

async function sendSignupOtpEmail({ to, otp, expiresMinutes }) {
  const smtpUser = SMTP_USER.value();
  const smtpPass = SMTP_APP_PASSWORD.value();
  const fromName = SMTP_FROM_NAME.value();

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  const subject = 'Your OTP Code - Sto. Rosario Parish Church';
  const text = `Your One-Time Password (OTP) is: ${otp}\n\nThis code will expire in ${expiresMinutes} minutes.`;
  const html = `
  <div style="font-family:Arial,Helvetica,sans-serif;background:${EMAIL_BRAND.bg};padding:24px;">
    <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid ${EMAIL_BRAND.border};">
      <div style="background:${EMAIL_BRAND.primaryBlue};padding:16px 20px;">
        <div style="font-size:16px;font-weight:700;color:#ffffff;">Sto. Rosario Parish Church</div>
        <div style="font-size:13px;color:#dbeafe;">Email Verification (OTP)</div>
      </div>
      <div style="padding:24px;">
        <div style="font-size:14px;color:${EMAIL_BRAND.text};line-height:1.6;">
          <div style="margin-bottom:12px;">Use this OTP to complete your sign up:</div>
          <div style="font-size:28px;font-weight:800;letter-spacing:6px;color:${EMAIL_BRAND.darkBlue};margin:12px 0;">${escapeHtml(otp)}</div>
          <div style="color:${EMAIL_BRAND.muted};font-size:12px;">This code expires in ${escapeHtml(String(expiresMinutes))} minutes. If you did not request this, you can ignore this email.</div>
        </div>
      </div>
    </div>
  </div>`;

  await transporter.sendMail({
    from: `${fromName} <${smtpUser}>`,
    to,
    subject,
    text,
    html,
  });
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const EMAIL_BRAND = {
  primaryBlue: '#1E40AF',
  darkBlue: '#1E3A8A',
  gold: '#FACC15',
  bg: '#EFF6FF',
  border: '#DBEAFE',
  text: '#111827',
  muted: '#6b7280',
  cardBorder: '#e5e7eb',
};

function extractFirstDateStringFromFields(fields) {
  if (!fields || typeof fields !== 'object') return '';
  let dateStr = '';
  for (const [k, v] of Object.entries(fields)) {
    if (dateStr) break;
    const key = String(k || '').toLowerCase();
    const val = String(v ?? '').trim();
    if (key.includes('date') || key.includes('petsa')) {
      const m = val.match(/\b(\d{4}-\d{2}-\d{2})\b/);
      if (m) dateStr = m[1];
    }
  }
  return dateStr;
}

function extractFirstTimeStringFromFields(fields) {
  if (!fields || typeof fields !== 'object') return '';
  let timeStr = '';
  for (const [k, v] of Object.entries(fields)) {
    if (timeStr) break;
    const key = String(k || '').toLowerCase();
    const val = String(v ?? '').replace(/\u00A0|\u202F/g, ' ').trim();
    if (key.includes('time') || key.includes('oras')) {
      const m = val.match(/\b(\d{1,2}(?::\d{2})?[\s\u00A0\u202F]*(?:[AaPp][Mm])?)\b/);
      if (m) timeStr = m[1];
    }
  }
  return timeStr;
}

function extractDateStringFromValue(value) {
  const val = String(value ?? '').trim();
  const match = val.match(/\b(\d{4}-\d{2}-\d{2})\b/);
  return match ? match[1] : '';
}

function extractTimeStringFromValue(value) {
  const val = String(value ?? '').replace(/\u00A0|\u202F/g, ' ').trim();
  const match = val.match(/\b(\d{1,2}(?::\d{2})?[\s\u00A0\u202F]*(?:[AaPp][Mm])?)\b/);
  return match ? String(match[1] || '').trim() : '';
}

function extractScheduleDateStringFromFields(fields, canonicalType) {
  if (!fields || typeof fields !== 'object') return '';
  const candidatesByType = {
    baptism: [fields['Registration - Date of Baptism']],
    confirmation: [fields['Date of Confirmation (Petsa ng Kumpil)']],
    wedding: [fields['Date of Wedding']],
    funeral: [fields['Burial Date'], fields['Burial Date (Petsa ng Libing)']],
    house_blessing: [fields['Date of Blessing']],
    anointing: [fields['Appointment Date']],
    mass_intention: [
      fields['Date of Mass (Petsa ng Misa)'],
      fields['Date of Mass'],
      fields['Mass Intention Date'],
      fields['Date of Mass Intention'],
    ],
    first_communion: [
      fields['Preferred Date (Petsa na Nais)'],
      fields['Date of First Communion'],
      fields['First Communion Date'],
    ],
  };

  for (const value of candidatesByType[canonicalType] || []) {
    const date = extractDateStringFromValue(value);
    if (date) return date;
  }

  return extractFirstDateStringFromFields(fields);
}

function extractScheduleTimeStringFromFields(fields, canonicalType) {
  if (!fields || typeof fields !== 'object') return '';
  const candidatesByType = {
    baptism: [fields['Registration - Time of Baptism']],
    confirmation: [fields['Time (Oras)']],
    wedding: [fields.Time],
    funeral: [fields['Burial Time'], fields['Burial Time (Oras ng Libing)']],
    house_blessing: [fields['Time of Blessing']],
    anointing: [fields['Appointment Time']],
    mass_intention: [
      fields['Time of Mass (Oras ng Misa)'],
      fields['Time of Mass'],
      fields['Mass Intention Time'],
      fields['Time of Mass Intention'],
    ],
    first_communion: [
      fields['Preferred Time (Oras na Nais)'],
      fields['Time of First Communion'],
      fields['First Communion Time'],
    ],
  };

  for (const value of candidatesByType[canonicalType] || []) {
    const time = extractTimeStringFromValue(value);
    if (time) return time;
  }

  return extractFirstTimeStringFromFields(fields);
}

function baptismFeeForDate(dateValue) {
  const raw = String(dateValue || '').trim();
  const match = raw.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
  if (!match) return 1650;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
    return 1650;
  }

  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCDay() === 0 ? 300 : 1650;
}

function baptismFeeLabelForDate(dateValue) {
  return baptismFeeForDate(dateValue) === 300 ? 'Sunday' : 'Monday to Saturday';
}

function parseTimeToMinutes(timeStr) {
  if (typeof timeStr !== 'string') return null;
  const raw = timeStr.replace(/\u00A0|\u202F/g, ' ').trim();
  if (!raw) return null;

  // Supports:
  // - 09:00
  // - 9:00
  // - 9:00 AM / 9:00PM
  const m = raw.match(/^(\d{1,2})(?::(\d{2}))?[\s\u00A0\u202F]*([AaPp][Mm])?$/);
  if (!m) return null;

  let h = Number(m[1]);
  const min = Number(m[2] || 0);
  if (!Number.isFinite(h) || !Number.isFinite(min) || min < 0 || min > 59) return null;

  const ampm = (m[3] || '').toLowerCase();
  if (ampm) {
    if (h < 1 || h > 12) return null;
    if (ampm === 'am') {
      h = h === 12 ? 0 : h;
    } else if (ampm === 'pm') {
      h = h === 12 ? 12 : h + 12;
    }
  } else {
    if (h < 0 || h > 23) return null;
    if (h >= 1 && h <= 5) h += 12;
  }

  return h * 60 + min;
}

function bookingScheduleValues(row, fallbackCanonicalType) {
  const data = row || {};
  const details = data.details || {};
  const fields = details.fields || {};
  const canonicalType =
    String(data.sacramentTypeKey || '').trim() ||
    canonicalSacramentType(data.sacramentType) ||
    fallbackCanonicalType ||
    '';

  return {
    canonicalType,
    date:
      String(data.date || '').trim() ||
      extractScheduleDateStringFromFields(fields, canonicalType),
    time:
      String(data.time || '').trim() ||
      extractScheduleTimeStringFromFields(fields, canonicalType),
  };
}

function canonicalSacramentType(value) {
  const s = String(value || '').toLowerCase();
  if (!s) return '';

  // English
  if (s.includes('bapt')) return 'baptism';
  if (s.includes('confirm')) return 'confirmation';
  if (s.includes('wedding') || s.includes('matrimony') || s.includes('marriage')) return 'wedding';
  if (s.includes('funeral')) return 'funeral';
  if (s.includes('house') && s.includes('bless')) return 'house_blessing';
  if (s.includes('anoint')) return 'anointing';
  if (s.includes('first') && s.includes('communion')) return 'first_communion';
  if (s.includes('mass') && s.includes('intention')) return 'mass_intention';

  // Tagalog
  if (s.includes('binyag')) return 'baptism';
  if (s.includes('kumpil')) return 'confirmation';
  if (s.includes('kasal')) return 'wedding';
  if (s.includes('yumao')) return 'funeral';
  if (s.includes('basbas') && s.includes('bahay')) return 'house_blessing';
  if (s.includes('pagpapahid')) return 'anointing';
  if (s.includes('unang') && s.includes('komunyon')) return 'first_communion';
  if (s.includes('intensyon') && s.includes('misa')) return 'mass_intention';

  return '';
}

// ==================== SCHEDULING CONFLICT DETECTION ====================

/** List of restricted service types that cannot overlap */
const RESTRICTED_SERVICES = [
  'baptism',
  'confirmation',
  'wedding',
  'funeral',
  'house_blessing',
  'anointing',
];

const ACTIVE_BOOKING_STATUSES = [
  'approved',
  'accepted',
  'confirmed',
  'paid',
  'Approved',
  'Accepted',
  'Confirmed',
  'Paid',
];

/**
 * Check if a sacrament type is restricted (cannot have overlapping bookings)
 */
function isRestrictedService(canonicalType) {
  return RESTRICTED_SERVICES.includes((canonicalType || '').toLowerCase());
}

/**
 * Check if a sacrament type is Mass Intention (allows multiple bookings)
 */
function isMassIntention(canonicalType) {
  return (canonicalType || '').toLowerCase() === 'mass_intention';
}

function schedulePeriodFromMinutes(minutes) {
  return minutes < 12 * 60 ? 'AM' : 'PM';
}

/**
 * Check for scheduling conflicts before creating a booking
 * @param {Object} db - Firestore database instance
 * @param {string} date - Booking date (YYYY-MM-DD)
 * @param {string} time - Booking time (HH:MM AM/PM or HH:MM)
 * @param {string} canonicalType - Canonical sacrament type
 * @param {string} excludeBookingId - Booking ID to exclude from check (for updates)
 * @returns {Object} Conflict result with conflict details or null if no conflict
 */
async function checkSchedulingConflict(db, date, time, canonicalType, excludeBookingId) {
  try {
    // Mass Intention allows multiple bookings at same time
    if (isMassIntention(canonicalType)) {
      console.log('checkSchedulingConflict: Mass Intention allows multiple bookings');
      return null; // No conflict
    }

    // Non-restricted services don't need conflict checking
    if (!isRestrictedService(canonicalType)) {
      console.log(`checkSchedulingConflict: ${canonicalType} is not a restricted service`);
      return null; // No conflict
    }

    // If no date provided, skip check
    if (!date || date.trim().length === 0) {
      console.log('checkSchedulingConflict: No date provided, skipping check');
      return null; // No conflict
    }

    console.log(`checkSchedulingConflict: Checking conflicts for ${canonicalType} on ${date} at ${time}`);
    const requestedMinutes = parseTimeToMinutes(time || '');
    if (requestedMinutes == null) {
      return {
        conflictingBookingId: '',
        conflictingSacramentType: canonicalType,
        conflictingUserName: 'System',
        conflictingDate: date,
        conflictingTime: time || 'Invalid time',
        message: 'A valid time is required to verify schedule availability.',
      };
    }
    const requestedPeriod = schedulePeriodFromMinutes(requestedMinutes);

    const newSnap = await db
      .collection('bookings')
      .where('date', '==', date)
      .where('status', 'in', ACTIVE_BOOKING_STATUSES)
      .get();
    const oldSnap = await db
      .collection('sacrament_requests')
      .where('status', 'in', ACTIVE_BOOKING_STATUSES)
      .get();

    // Check each booking for time overlap
    for (const doc of [...newSnap.docs, ...oldSnap.docs]) {
      const booking = doc.data();
      
      // Skip if this is the same booking (during updates)
      if (excludeBookingId && doc.id === excludeBookingId) {
        continue;
      }

      const {
        canonicalType: bookingCanonicalType,
        date: bookingDate,
        time: bookingTime,
      } = bookingScheduleValues(booking, canonicalType);
      if (!isRestrictedService(bookingCanonicalType)) {
        continue;
      }
      if (bookingDate !== date) {
        continue;
      }

      // Check if booking time matches (if time is specified)
      if (time && time.trim().length > 0 && bookingTime && bookingTime.trim().length > 0) {
        const bookingMinutes = parseTimeToMinutes(String(bookingTime || ''));

        if (bookingMinutes == null) continue;

        if (Math.abs(requestedMinutes - bookingMinutes) < 60) {
          console.log(`checkSchedulingConflict: 1-hour overlap detected with booking ${doc.id}`);
          return {
            conflictingBookingId: doc.id,
            conflictingSacramentType: booking.sacramentType,
            conflictingUserName: booking.userName || 'Another Parishioner',
            conflictingDate: date,
            conflictingTime: bookingTime,
            message: 'The selected date and time overlaps with another approved booking. Please choose a time at least 1 hour apart.',
          };
        }

        const bookingPeriod = schedulePeriodFromMinutes(bookingMinutes);
        if (
          bookingCanonicalType === canonicalType &&
          bookingPeriod === requestedPeriod
        ) {
          console.log(`checkSchedulingConflict: ${requestedPeriod} period already occupied by booking ${doc.id}`);
          return {
            conflictingBookingId: doc.id,
            conflictingSacramentType: booking.sacramentType,
            conflictingUserName: booking.userName || 'Another Parishioner',
            conflictingDate: date,
            conflictingTime: bookingTime,
            message: `Only 1 ${canonicalType} booking is allowed in the ${requestedPeriod} schedule for this date. Please choose another available schedule.`,
          };
        }
      } else if (!time || time.trim().length === 0) {
        // If time not specified but date matches, it's a potential conflict
        // (since we can't determine exact timing)
        console.log(`checkSchedulingConflict: POTENTIAL CONFLICT (no time specified) with booking ${doc.id}`);
        return {
          conflictingBookingId: doc.id,
          conflictingSacramentType: booking.sacramentType,
          conflictingUserName: booking.userName || 'Another Parishioner',
          conflictingDate: date,
          conflictingTime: bookingTime || 'Not specified',
        };
      }
    }

    console.log('checkSchedulingConflict: No conflicts detected');
    return null; // No conflict
  } catch (error) {
    console.error('checkSchedulingConflict error:', error);
    throw new HttpsError(
      'internal',
      'Unable to verify schedule availability. Please try again before submitting.'
    );
  }
}

/**
 * Validate Mass Intention schedule against official Mass schedules
 * @param {Object} db - Firestore database instance
 * @param {string} date - Date (YYYY-MM-DD)
 * @param {string} time - Time (HH:MM AM/PM or HH:MM)
 * @returns {boolean} true if valid Mass schedule exists
 */
async function validateMassIntentionSchedule(db, date, time) {
  try {
    if (!date || !time) {
      console.log('validateMassIntentionSchedule: Missing date or time');
      return false;
    }

    const requestedMinutes = parseTimeToMinutes(time);
    if (requestedMinutes == null) {
      console.log('validateMassIntentionSchedule: Invalid time format');
      return false;
    }

    const parsedDate = new Date(`${date}T00:00:00Z`);
    const dayOfWeek = getDayName(parsedDate);

    async function scheduleExists(collectionName) {
      const dateSnapshot = await db
        .collection(collectionName)
        .where('date', '==', date)
        .get();

      for (const doc of dateSnapshot.docs) {
        const schedule = doc.data() || {};
        const scheduleTime = String(
          schedule.time || schedule.timeString || schedule.startTime || ''
        ).trim();
        if (parseTimeToMinutes(scheduleTime) === requestedMinutes) {
          return true;
        }
      }

      const daySnapshot = await db
        .collection(collectionName)
        .where('dayOfWeek', '==', dayOfWeek)
        .get();

      for (const doc of daySnapshot.docs) {
        const schedule = doc.data() || {};
        if (schedule.active === false) continue;

        const scheduleTime = String(
          schedule.time || schedule.timeString || schedule.startTime || ''
        ).trim();
        if (parseTimeToMinutes(scheduleTime) === requestedMinutes) {
          return true;
        }
      }

      return false;
    }

    function profileScheduleTexts(data) {
      const raw =
        data?.massSchedule ??
        data?.mass_schedule ??
        data?.massSchedules ??
        data?.schedule;
      const texts = [];

      function addFrom(value) {
        if (value == null) return;
        if (typeof value === 'string') {
          const trimmed = value.trim();
          if (trimmed) texts.push(trimmed);
          return;
        }
        if (Array.isArray(value)) {
          value.forEach(addFrom);
          return;
        }
        if (typeof value === 'object') {
          let foundNestedSchedule = false;
          for (const key of ['massSchedule', 'mass_schedule', 'massSchedules', 'schedule']) {
            if (value[key] !== undefined) {
              addFrom(value[key]);
              foundNestedSchedule = true;
            }
          }
          if (foundNestedSchedule) return;

          const day = String(
            value.day || value.englishDay || value.tagalogDay || value.label || ''
          ).trim();
          const scheduleTime = String(
            value.time || value.timeString || value.scheduleTime || value.startTime || ''
          ).trim();
          const combined = [day, scheduleTime].filter(Boolean).join(' at ').trim();
          if (combined) texts.push(combined);
        }
      }

      addFrom(raw);
      if (texts.length === 0 && data && typeof data === 'object') {
        Object.values(data).forEach(addFrom);
      }
      return texts;
    }

    function parseAllTimesToMinutes(value) {
      const times = [];
      const regex = /\b(\d{1,2})(?::(\d{2}))?[\s\u00A0\u202F]*([AaPp][Mm])\b/g;
      let match;
      const normalizedValue = String(value || '').replace(/\u00A0|\u202F/g, ' ');
      while ((match = regex.exec(normalizedValue)) !== null) {
        const minutes = parseTimeToMinutes(`${match[1]}:${match[2] || '00'} ${match[3]}`);
        if (minutes != null && !times.includes(minutes)) times.push(minutes);
      }
      return times;
    }

    function scheduleTextAppliesToDate(value) {
      const text = String(value || '').toLowerCase();
      const weekday = parsedDate.getUTCDay() === 0 ? 7 : parsedDate.getUTCDay();

      if (
        text.includes('mon-sat') ||
        text.includes('monday-saturday') ||
        text.includes('monday to saturday')
      ) {
        return weekday >= 1 && weekday <= 6;
      }
      if (
        text.includes('mon-fri') ||
        text.includes('monday-friday') ||
        text.includes('monday to friday') ||
        text.includes('weekdays')
      ) {
        return weekday >= 1 && weekday <= 5;
      }
      if (text.includes('daily') || text.includes('everyday')) return true;

      const names = {
        1: ['monday', 'mon'],
        2: ['tuesday', 'tue'],
        3: ['wednesday', 'wed'],
        4: ['thursday', 'thu'],
        5: ['friday', 'fri'],
        6: ['saturday', 'sat'],
        7: ['sunday', 'sun'],
      };

      const mentionedDays = Object.entries(names)
        .filter(([, aliases]) => aliases.some(alias => text.includes(alias)))
        .map(([day]) => Number(day));

      if (mentionedDays.length === 0) return true;
      return mentionedDays.includes(weekday);
    }

    async function profileScheduleExists() {
      const docs = [];

      async function addDoc(doc) {
        if (!doc.exists) return;
        if (!docs.some(existing => existing.ref.path === doc.ref.path)) {
          docs.push(doc);
        }
      }

      async function addCollection(collectionName) {
        try {
          const snapshot = await db.collection(collectionName).limit(20).get();
          for (const doc of snapshot.docs) {
            await addDoc(doc);
          }
        } catch (err) {
          console.warn(`validateMassIntentionSchedule: Could not read ${collectionName}`, err?.message || err);
        }
      }

      try {
        await addDoc(await db.collection('parish_profile').doc('main').get());
      } catch (err) {
        console.warn('validateMassIntentionSchedule: Could not read parish_profile/main', err?.message || err);
      }

      await addCollection('parish_profile');
      await addCollection('schedule');
      await addCollection('schedules');

      for (const doc of docs) {
        for (const text of profileScheduleTexts(doc.data() || {})) {
          if (!scheduleTextAppliesToDate(text)) continue;
          if (parseAllTimesToMinutes(text).includes(requestedMinutes)) {
            return true;
          }
        }
      }

      return false;
    }

    const isValid =
      await scheduleExists('mass_schedules') ||
      await scheduleExists('massSchedules') ||
      await profileScheduleExists();
    console.log(`validateMassIntentionSchedule: Mass schedule ${isValid ? 'FOUND' : 'NOT FOUND'} for ${date} at ${time}`);
    return isValid;
  } catch (error) {
    console.error('validateMassIntentionSchedule error:', error);
    return false;
  }
}

// =========================================================================

async function sendReceiptEmail({
  to,
  donorName,
  amount,
  referenceId,
  paidAt,
}) {
  const smtpUser = SMTP_USER.value();
  const smtpPass = SMTP_APP_PASSWORD.value();
  const fromName = SMTP_FROM_NAME.value();

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  const paidAtStr = paidAt.toLocaleString('en-PH', { timeZone: 'Asia/Manila' });

  const subject = 'Donation Receipt - Sto. Rosario Parish Church';
  const text =
    `Thank you for your donation.\n\n` +
    `Donor: ${donorName}\n` +
    `Amount: ${formatPhp(amount)}\n` +
    `Reference ID: ${referenceId}\n` +
    `Date/Time: ${paidAtStr}\n`;

  const html = `
  <div style="font-family:Arial,Helvetica,sans-serif;background:${EMAIL_BRAND.bg};padding:24px;">
    <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid ${EMAIL_BRAND.border};">
      <div style="background:${EMAIL_BRAND.primaryBlue};padding:16px 20px;">
        <div style="font-size:16px;font-weight:700;color:#ffffff;">Sto. Rosario Parish Church</div>
        <div style="font-size:13px;color:#dbeafe;">Donation Receipt</div>
      </div>

      <div style="padding:24px;">

      <div style="font-size:14px;color:${EMAIL_BRAND.text};line-height:1.6;">
        <div style="margin-bottom:12px;">Hello <strong>${escapeHtml(donorName || 'Donor')}</strong>,</div>
        <div style="margin-bottom:16px;">Thank you for your donation. This email serves as your official receipt.</div>
      </div>

      <div style="height:4px;background:${EMAIL_BRAND.gold};border-radius:999px;margin:16px 0;"></div>

      <div style="font-size:14px;color:${EMAIL_BRAND.text};">
        <div style="font-weight:700;margin-bottom:8px;">Receipt Summary</div>
        <table style="width:100%;border-collapse:collapse;">
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Donor</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:600;">${escapeHtml(donorName || 'Donor')}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Amount</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:700;">${escapeHtml(formatPhp(amount))}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Reference ID</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(referenceId)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Date/Time</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(paidAtStr)}</td></tr>
        </table>
      </div>

      <div style="border-top:1px solid ${EMAIL_BRAND.cardBorder};margin:16px 0;"></div>

      <div style="font-size:12px;color:${EMAIL_BRAND.muted};line-height:1.6;">
        If you have questions about this receipt, you may reply to this email.
      </div>
      </div>
    </div>
  </div>`;

  await transporter.sendMail({
    from: `${fromName} <${smtpUser}>`,
    to,
    subject,
    text,
    html,
  });
}

function xenditAuthHeader() {
  const secretKey = XENDIT_SECRET_KEY.value();
  if (typeof secretKey !== 'string' || secretKey.trim().length === 0) {
    throw new HttpsError('failed-precondition', 'Missing XENDIT_SECRET_KEY secret.');
  }
  const token = Buffer.from(`${secretKey.trim()}:`).toString('base64');
  return `Basic ${token}`;
}

async function createXenditInvoice({
  externalId,
  amount,
  payerEmail,
  description,
  customerName,
}) {
  const rawEmail = String(payerEmail || '').trim();
  const fallbackEmail = 'anonymous@sto-rosario-parish.local';
  const normalizedEmail = rawEmail.length > 0 ? rawEmail : fallbackEmail;
  const normalizedCustomerName = String(customerName || '').trim() || 'Donor';

  const requestBody = {
    external_id: externalId,
    amount,
    payer_email: normalizedEmail,
    description,
    currency: 'PHP',
    customer: {
      given_names: normalizedCustomerName,
      email: normalizedEmail,
    },
  };

  const response = await fetch('https://api.xendit.co/v2/invoices', {
    method: 'POST',
    headers: {
      Authorization: xenditAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  });

  const bodyText = await response.text();
  let data = null;
  try {
    data = JSON.parse(bodyText);
  } catch (_) {
    data = null;
  }

  if (!response.ok) {
    console.error('Xendit invoice create failed', {
      status: response.status,
      requestBody,
      body: bodyText,
    });
    throw new HttpsError('internal', `Xendit invoice creation failed (HTTP ${response.status}).`);
  }

  if (!data || !data.invoice_url) {
    console.error('Xendit invoice missing URL', {
      requestBody,
      body: bodyText,
      parsedData: data,
    });
    throw new HttpsError('internal', 'Xendit did not return an invoice URL.');
  }

  return data || {};
}

async function sendBookingConfirmationEmail({
  to,
  bookingId,
  booking,
  paidAt,
  transactionRef,
}) {
  await sendBookingStatusEmail({
    to,
    bookingId,
    booking,
    statusLabel: 'Confirmed',
    introLine: 'Your booking has been confirmed by Sto. Rosario Parish Church.',
    paidAt,
    transactionRef,
  });
}

async function sendBookingStatusEmail({
  to,
  bookingId,
  booking,
  statusLabel,
  introLine,
  paidAt,
  transactionRef,
}) {
  const smtpUser = SMTP_USER.value();
  const smtpPass = SMTP_APP_PASSWORD.value();
  const fromName = SMTP_FROM_NAME.value();

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  const paidAtStr = paidAt
    ? paidAt.toLocaleString('en-PH', { timeZone: 'Asia/Manila' })
    : '';

  const userName = String(booking?.userName || '');
  const userEmail = String(booking?.userEmail || '');
  const sacramentType = String(booking?.sacramentType || '');
  const date = String(booking?.date || '') || extractFirstDateStringFromFields(booking?.details?.fields);
  const time = String(booking?.time || '') || extractFirstTimeStringFromFields(booking?.details?.fields);
  const amount = Number(booking?.amount || 0);
  const feeBreakdown = booking?.feeBreakdown && typeof booking.feeBreakdown === 'object'
    ? booking.feeBreakdown
    : {};

  const fields = booking?.details?.fields && typeof booking.details.fields === 'object'
    ? booking.details.fields
    : {};
  const displayName = userName || 'Parishioner';
  const displaySacrament = sacramentType || 'Sacrament Booking';
  const scheduleText = `${date || 'N/A'}${time ? ` at ${time}` : ''}`;
  const paymentText = Number.isFinite(amount) && amount > 0 ? formatPhp(amount) : 'N/A';
  
  // Handle wedding add-ons if present
  const weddingAddons = booking?.weddingAddons && Array.isArray(booking.weddingAddons) ? booking.weddingAddons : [];
  const addonsHtml = weddingAddons.length > 0
    ? `
      <tr><td colspan="2" style="padding:6px 0;"></td></tr>
      <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};font-weight:700;">Selected Add-ons:</td><td></td></tr>
      ${weddingAddons.map(addon => `<tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};padding-left:12px;">• ${escapeHtml(addon.name)}</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${formatPhp(addon.price)}</td></tr>`).join('')}
    `
    : '';

  const subject = `Booking ${statusLabel}: ${displaySacrament} (Ref ${bookingId})`;
  const text =
    `Hello ${displayName},\n\n` +
    `${introLine}\n\n` +
    `BOOKING SUMMARY\n` +
    `Booking Reference: ${bookingId}\n` +
    `Sacrament Type: ${displaySacrament}\n` +
    `Scheduled Date/Time: ${scheduleText}\n` +
    `Status: ${statusLabel}\n` +
    `Total Payment: ${paymentText}\n` +
    `${transactionRef ? `Transaction Reference: ${transactionRef}\n` : ''}` +
    `${paidAtStr ? `Paid At: ${paidAtStr}\n` : ''}` +
    `\n` +
    `CUSTOMER DETAILS\n` +
    `Name: ${displayName}\n` +
    `Email: ${userEmail || to}\n\n` +
    `If you have questions or need to make changes, please reply to this email.\n`;


  const html = `
  <div style="font-family:Arial,Helvetica,sans-serif;background:${EMAIL_BRAND.bg};padding:24px;">
    <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid ${EMAIL_BRAND.border};">
      <div style="background:${EMAIL_BRAND.primaryBlue};padding:16px 20px;">
        <div style="font-size:16px;font-weight:700;color:#ffffff;">Sto. Rosario Parish Church</div>
        <div style="font-size:13px;color:#dbeafe;">Booking ${escapeHtml(statusLabel)}</div>
      </div>

      <div style="padding:24px;">

      <div style="font-size:14px;color:${EMAIL_BRAND.text};line-height:1.6;">
        <div style="margin-bottom:12px;">Hello <strong>${escapeHtml(displayName)}</strong>,</div>
        <div style="margin-bottom:16px;">${escapeHtml(introLine)} Please review your details below.</div>
      </div>

      <div style="height:4px;background:${EMAIL_BRAND.gold};border-radius:999px;margin:16px 0;"></div>

      <div style="font-size:14px;color:${EMAIL_BRAND.text};">
        <div style="font-weight:700;margin-bottom:8px;">Booking Summary</div>
        <table style="width:100%;border-collapse:collapse;">
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Booking Reference</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:600;">${escapeHtml(bookingId)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Sacrament Type</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:600;">${escapeHtml(displaySacrament)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Scheduled Date/Time</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:600;">${escapeHtml(scheduleText)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Status</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:600;">${escapeHtml(statusLabel)}</td></tr>
          ${addonsHtml}
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Total Payment</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:700;">${escapeHtml(paymentText)}</td></tr>
          ${transactionRef ? `<tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Transaction Ref</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(transactionRef)}</td></tr>` : ''}
          ${paidAtStr ? `<tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Paid At</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(paidAtStr)}</td></tr>` : ''}
        </table>
      </div>

      <div style="border-top:1px solid ${EMAIL_BRAND.cardBorder};margin:16px 0;"></div>

      <div style="font-size:14px;color:${EMAIL_BRAND.text};">
        <div style="font-weight:700;margin-bottom:8px;">Customer Details</div>
        <table style="width:100%;border-collapse:collapse;">
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Name</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(displayName)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Email</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(userEmail || to)}</td></tr>
        </table>
      </div>

      <div style="border-top:1px solid ${EMAIL_BRAND.cardBorder};margin:16px 0;"></div>

      <div style="font-size:12px;color:${EMAIL_BRAND.muted};line-height:1.6;">
        If you have questions or need to update your booking, simply reply to this email.
      </div>
      </div>
    </div>
  </div>`;

  await transporter.sendMail({
    from: `${fromName} <${smtpUser}>`,
    to,
    replyTo: smtpUser,
    subject,
    text,
    html,
  });
}

async function sendBookingAlreadyPaidEmail({
  to,
  bookingId,
  booking,
}) {
  await sendBookingStatusEmail({
    to,
    bookingId,
    booking,
    statusLabel: 'Paid',
    introLine: 'Your booking has already been paid. No additional payment is required.',
    paidAt: booking?.xendit?.paidAt?.toDate
      ? booking.xendit.paidAt.toDate()
      : new Date(),
    transactionRef: String(booking?.xendit?.invoiceId || bookingId),
  });
}

async function maybeSendBookingAlreadyPaidEmail({ bookingRef, bookingData }) {
  const to = String(bookingData?.userEmail || bookingData?.email || '').trim();
  if (!isValidEmail(to)) return;

  const latestSnap = await bookingRef.get();
  const latestData = latestSnap.data() || {};
  if (latestData?.notifications?.alreadyPaidEmailSentAt) return;

  await sendBookingAlreadyPaidEmail({
    to,
    bookingId: bookingRef.id,
    booking: bookingData,
  });

  await bookingRef.set(
    {
      notifications: {
        alreadyPaidEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    { merge: true }
  );
}

async function sendDonationContactEmails({
  donationId,
  donorName,
  donorEmail,
  donationType,
  amount,
  phone,
  items,
  description,
  message,
}) {
  const smtpUser = SMTP_USER.value();
  const smtpPass = SMTP_APP_PASSWORD.value();
  const fromName = SMTP_FROM_NAME.value();

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  const parishSubject = `New Donation Inquiry (${donationType}) - ${donorName}`;
  const parishText =
    `A new donation inquiry was submitted.\n\n` +
    `Donation ID: ${donationId}\n` +
    `Type: ${donationType}\n` +
    `Donor: ${donorName}\n` +
    `Email: ${donorEmail}\n` +
    `Phone: ${phone || ''}\n` +
    `Amount: ${Number.isFinite(amount) ? formatPhp(amount) : ''}\n` +
    `Items: ${items || ''}\n` +
    `Description: ${description || ''}\n` +
    `Message: ${message || ''}\n\n` +
    `You can reply directly to this email to contact the donor.`;

  const parishHtml = `
  <div style="font-family:Arial,Helvetica,sans-serif;background:${EMAIL_BRAND.bg};padding:24px;">
    <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid ${EMAIL_BRAND.border};">
      <div style="background:${EMAIL_BRAND.primaryBlue};padding:16px 20px;">
        <div style="font-size:16px;font-weight:700;color:#ffffff;">Sto. Rosario Parish Church</div>
        <div style="font-size:13px;color:#dbeafe;">New Donation Inquiry</div>
      </div>

      <div style="padding:24px;">

      <div style="font-size:14px;color:${EMAIL_BRAND.text};line-height:1.6;">
        A new donation inquiry has been submitted. Details are below.
      </div>

      <div style="height:4px;background:${EMAIL_BRAND.gold};border-radius:999px;margin:16px 0;"></div>

      <div style="font-size:14px;color:${EMAIL_BRAND.text};">
        <div style="font-weight:700;margin-bottom:8px;">Inquiry Details</div>
        <table style="width:100%;border-collapse:collapse;">
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Donation ID</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:600;">${escapeHtml(donationId)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Type</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(donationType)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Donor</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(donorName)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Email</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(donorEmail)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Phone</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(phone || '')}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Amount</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:700;">${escapeHtml(Number.isFinite(amount) ? formatPhp(amount) : '')}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Items</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(items || '')}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Description</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(description || '')}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Message</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(message || '')}</td></tr>
        </table>
      </div>

      <div style="border-top:1px solid ${EMAIL_BRAND.cardBorder};margin:16px 0;"></div>

      <div style="font-size:12px;color:${EMAIL_BRAND.muted};line-height:1.6;">
        You can reply directly to this email to contact the donor.
      </div>
      </div>
    </div>
  </div>`;

  await transporter.sendMail({
    from: `${fromName} <${smtpUser}>`,
    to: smtpUser,
    replyTo: donorEmail,
    subject: parishSubject,
    text: parishText,
    html: parishHtml,
  });

  const donorSubject = 'We received your donation inquiry - Sto. Rosario Parish Church';
  const donorText =
    `Thank you for reaching out.\n\n` +
    `We received your donation inquiry and will contact you soon.\n\n` +
    `Donation ID: ${donationId}\n` +
    `Type: ${donationType}\n` +
    `Name: ${donorName}\n` +
    `Email: ${donorEmail}\n\n` +
    `If you need to follow up, you may reply to this email.\n` +
    `Parish email: ${smtpUser}\n`;

  const donorHtml = `
  <div style="font-family:Arial,Helvetica,sans-serif;background:${EMAIL_BRAND.bg};padding:24px;">
    <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid ${EMAIL_BRAND.border};">
      <div style="background:${EMAIL_BRAND.primaryBlue};padding:16px 20px;">
        <div style="font-size:16px;font-weight:700;color:#ffffff;">Sto. Rosario Parish Church</div>
        <div style="font-size:13px;color:#dbeafe;">Donation Inquiry Received</div>
      </div>

      <div style="padding:24px;">

      <div style="font-size:14px;color:${EMAIL_BRAND.text};line-height:1.6;">
        <div style="margin-bottom:12px;">Hello <strong>${escapeHtml(donorName || 'Donor')}</strong>,</div>
        <div style="margin-bottom:16px;">We received your donation inquiry. Thank you for your generosity. Our team will contact you soon if we need more details.</div>
      </div>

      <div style="height:4px;background:${EMAIL_BRAND.gold};border-radius:999px;margin:16px 0;"></div>

      <div style="font-size:14px;color:${EMAIL_BRAND.text};">
        <div style="font-weight:700;margin-bottom:8px;">Inquiry Summary</div>
        <table style="width:100%;border-collapse:collapse;">
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Donation ID</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:600;">${escapeHtml(donationId)}</td></tr>
          <tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Type</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};">${escapeHtml(donationType)}</td></tr>
          ${Number.isFinite(amount) && amount > 0 ? `<tr><td style="padding:6px 0;color:${EMAIL_BRAND.muted};">Amount</td><td style="padding:6px 0;text-align:right;color:${EMAIL_BRAND.text};font-weight:700;">${escapeHtml(formatPhp(amount))}</td></tr>` : ''}
        </table>
      </div>

      <div style="border-top:1px solid ${EMAIL_BRAND.cardBorder};margin:16px 0;"></div>

      <div style="font-size:12px;color:${EMAIL_BRAND.muted};line-height:1.6;">
        If you need to follow up, simply reply to this email.
        <br/>Parish email: ${escapeHtml(smtpUser)}
      </div>
      </div>
    </div>
  </div>`;

  await transporter.sendMail({
    from: `${fromName} <${smtpUser}>`,
    to: donorEmail,
    replyTo: smtpUser,
    subject: donorSubject,
    text: donorText,
    html: donorHtml,
  });
}

exports.createXenditDonationInvoice = onCall(
  {
    region: 'asia-southeast1',
    secrets: [XENDIT_SECRET_KEY, SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (request) => {
    try {
      const data = request.data || {};

      // Normalize fields to accept both canonical and alias fields
      const normalizedData = normalizeFields(data, 'donation');
      
      // Validate required canonical fields
      const validationErrors = validateCanonicalFields(normalizedData, 'donation');
      if (validationErrors.length > 0) {
        throw new HttpsError('invalid-argument', `Validation failed: ${validationErrors.join(', ')}`);
      }

      const donationType = (normalizedData.donationType || 'monetary').toString();
      const isAnonymous = Boolean(normalizedData.isAnonymous);

      const amountNumber = Number(normalizedData.amount);
      if (!Number.isFinite(amountNumber) || amountNumber <= 0) {
        throw new HttpsError('invalid-argument', 'Amount must be a number greater than zero.');
      }

      const uid = request.auth?.uid || '';
      const isAuthenticated = !!uid;
      
      // Name is required for guest non-anonymous donations
      let donorName;
      if (isAnonymous) {
        donorName = 'Anonymous';
      } else if (!isAuthenticated) {
        // Guest non-anonymous: name is required
        donorName = (normalizedData.name || '').toString().trim();
        if (!donorName) {
          throw new HttpsError('invalid-argument', 'Name is required for non-anonymous donations.');
        }
      } else {
        // Logged-in non-anonymous: use provided name or default
        donorName = (normalizedData.name || request.auth?.token?.name || 'Anonymous').toString().trim() || 'Anonymous';
      }
      
      const donorEmail = (normalizedData.email || '').toString().trim();
      // Email is optional for anonymous, required for non-anonymous
      if (!isAnonymous && !isValidEmail(donorEmail)) {
        throw new HttpsError('invalid-argument', 'A valid email address is required for non-anonymous donations.');
      }

      const userName = request.auth?.token?.name || donorName;
      const userEmail = request.auth?.token?.email || donorEmail;

      const db = admin.firestore();
      const collectionName = donationType === 'massOffering' ? 'mass_offerings' : 'donations';
      const structuredId = await generateStructuredId(db, donationType === 'massOffering' ? 'mass_offering' : 'donation');
      const donationRef = db.collection(collectionName).doc(structuredId);

      const invoice = await createXenditInvoice({
        externalId: structuredId,
        amount: amountNumber,
        payerEmail: donorEmail,
        description: 'Donation - Sto. Rosario Parish Church',
        customerName: donorName,
      });

      const invoiceId = String(invoice?.id || '').trim();
      const invoiceUrl = String(invoice?.invoice_url || '').trim();
      const invoiceStatus = String(invoice?.status || 'PENDING').trim();
      if (!invoiceId || !invoiceUrl) {
        throw new HttpsError('internal', 'Xendit did not return an invoice URL.');
      }

      await donationRef.set({
        structuredId: structuredId,
        userId: uid,
        userName,
        userEmail,
        donationType,
        isAnonymous,
        amount: amountNumber,
        currency: 'PHP',
        paymentMethod: 'xendit',
        name: donorName,
        email: donorEmail,
        phone: (normalizedData.phone || '').toString().trim(),
        items: (normalizedData.items || '').toString().trim(),
        description: (normalizedData.description || '').toString().trim(),
        offeringLocation: (normalizedData.offeringLocation || '').toString().trim(),
        message: (normalizedData.message || '').toString().trim(),
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
        xendit: {
          invoiceId,
          invoiceUrl,
          status: invoiceStatus.toLowerCase(),
        },
      });

      return {
        donationId: donationRef.id,
        checkoutUrl: invoiceUrl,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('createXenditDonationInvoice unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', err?.message ? String(err.message) : 'Unknown internal error');
    }
  }
);

exports.createXenditMassOfferingInvoice = onCall(
  {
    region: 'asia-southeast1',
    secrets: [XENDIT_SECRET_KEY, SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (request) => {
    try {
      const data = request.data || {};

      // Normalize fields to accept both canonical and alias fields
      const normalizedData = normalizeFields(data, 'donation');

      // Validate required canonical fields
      const validationErrors = validateCanonicalFields(normalizedData, 'donation');
      if (validationErrors.length > 0) {
        throw new HttpsError('invalid-argument', `Validation failed: ${validationErrors.join(', ')}`);
      }

      const donationType = (normalizedData.donationType || 'monetary').toString();
      if (donationType !== 'massOffering') {
        throw new HttpsError('invalid-argument', 'donationType must be massOffering for this function.');
      }

      const isAnonymous = Boolean(normalizedData.isAnonymous);
      const amountNumber = Number(normalizedData.amount);
      if (!Number.isFinite(amountNumber) || amountNumber <= 0) {
        throw new HttpsError('invalid-argument', 'Amount must be a number greater than zero.');
      }

      const offeringLocation = (normalizedData.offeringLocation || '').toString().trim();
      if (!offeringLocation) {
        throw new HttpsError('invalid-argument', 'offeringLocation is required for mass offerings.');
      }

      const uid = request.auth?.uid || '';
      const isAuthenticated = !!uid;

      let donorName;
      if (isAnonymous) {
        donorName = 'Anonymous';
      } else if (!isAuthenticated) {
        donorName = (normalizedData.name || '').toString().trim();
        if (!donorName) {
          throw new HttpsError('invalid-argument', 'Name is required for non-anonymous mass offerings.');
        }
      } else {
        donorName = (normalizedData.name || request.auth?.token?.name || 'Anonymous').toString().trim() || 'Anonymous';
      }

      const donorEmail = (normalizedData.email || '').toString().trim();
      if (!isAnonymous && !isValidEmail(donorEmail)) {
        throw new HttpsError('invalid-argument', 'A valid email address is required for non-anonymous mass offerings.');
      }

      const userName = request.auth?.token?.name || donorName;
      const userEmail = request.auth?.token?.email || donorEmail;

      const db = admin.firestore();
      const structuredId = await generateStructuredId(db, 'mass_offering');
      const offeringRef = db.collection('mass_offerings').doc(structuredId);

      const invoice = await createXenditInvoice({
        externalId: structuredId,
        amount: amountNumber,
        payerEmail: donorEmail,
        description: 'Mass Offering - Sto. Rosario Parish Church',
        customerName: donorName,
      });

      const invoiceId = String(invoice?.id || '').trim();
      const invoiceUrl = String(invoice?.invoice_url || '').trim();
      const invoiceStatus = String(invoice?.status || 'PENDING').trim();
      if (!invoiceId || !invoiceUrl) {
        throw new HttpsError('internal', 'Xendit did not return an invoice URL.');
      }

      await offeringRef.set({
        structuredId,
        userId: uid,
        userName,
        userEmail,
        donationType,
        isAnonymous,
        amount: amountNumber,
        currency: 'PHP',
        paymentMethod: 'xendit',
        name: donorName,
        email: donorEmail,
        phone: (normalizedData.phone || '').toString().trim(),
        items: (normalizedData.items || '').toString().trim(),
        description: (normalizedData.description || '').toString().trim(),
        offeringLocation,
        message: (normalizedData.message || '').toString().trim(),
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
        xendit: {
          invoiceId,
          invoiceUrl,
          status: invoiceStatus.toLowerCase(),
        },
      });

      return {
        donationId: offeringRef.id,
        checkoutUrl: invoiceUrl,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('createXenditMassOfferingInvoice unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', err?.message ? String(err.message) : 'Unknown internal error');
    }
  }
);

exports.requestSignupOtp = onCall(
  {
    region: 'asia-southeast1',
    secrets: [SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (request) => {
    try {
      const data = request.data || {};
      const email = normalizeEmail(requireNonEmptyString(data.email, 'email'));
      if (!isValidEmail(email)) {
        throw new HttpsError('invalid-argument', 'A valid email address is required.');
      }

      const db = admin.firestore();

      // Prevent OTP requests for emails that already exist in Firebase Auth.
      try {
        await admin.auth().getUserByEmail(email);
        throw new HttpsError('already-exists', 'Email is already registered. Please log in instead.');
      } catch (authErr) {
        if (authErr?.code !== 'auth/user-not-found') {
          if (authErr instanceof HttpsError) throw authErr;
          throw authErr;
        }
      }

      const otp = generateOtpCode();
      const salt = crypto.randomBytes(16).toString('hex');
      const otpHash = hashOtp({ email, otp, salt });
      const now = Date.now();
      const expiresMinutes = 10;
      const expiresAtMs = now + expiresMinutes * 60 * 1000;

      const docId = crypto.createHash('sha256').update(email).digest('hex');
      const ref = db.collection('signup_otps').doc(docId);

      await ref.set(
        {
          email,
          otpHash,
          salt,
          attempts: 0,
          usedAt: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMs),
        },
        { merge: true }
      );

      await sendSignupOtpEmail({ to: email, otp, expiresMinutes });

      return {
        status: 'ok',
        expiresMinutes,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('requestSignupOtp unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', err?.message ? String(err.message) : 'Unknown internal error');
    }
  }
);

exports.verifySignupOtpAndCreateAccount = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    try {
      const data = request.data || {};
      const firstName = data.firstName ? String(data.firstName).trim() : '';
      const lastName = data.lastName ? String(data.lastName).trim() : '';
      const fullName = `${firstName} ${lastName}`.trim();
      const email = normalizeEmail(requireNonEmptyString(data.email, 'email'));
      const password = requireNonEmptyString(data.password, 'password');
      const otp = requireNonEmptyString(data.otp, 'otp');
      const sex = data.sex ? String(data.sex).trim().toLowerCase() : '';
      const birthdayRaw = data.birthday ? String(data.birthday).trim() : '';
      const birthday = birthdayRaw ? new Date(birthdayRaw) : null;
      const address = data.address ? String(data.address).trim() : '';
      const barangay = data.barangay ? String(data.barangay).trim() : '';

      if (!isValidEmail(email)) {
        throw new HttpsError('invalid-argument', 'A valid email address is required.');
      }
      if (!/^\d{6}$/.test(otp)) {
        throw new HttpsError('invalid-argument', 'OTP must be a 6-digit code.');
      }
      if (sex && !['female', 'male'].includes(sex)) {
        throw new HttpsError('invalid-argument', 'Sex must be either female or male.');
      }
      if (birthdayRaw && Number.isNaN(birthday.getTime())) {
        throw new HttpsError('invalid-argument', 'Birthday must be a valid date.');
      }
      if (birthday && birthday > new Date()) {
        throw new HttpsError('invalid-argument', 'Birthday cannot be in the future.');
      }

      const db = admin.firestore();
      const docId = crypto.createHash('sha256').update(email).digest('hex');
      const ref = db.collection('signup_otps').doc(docId);

      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError('failed-precondition', 'No OTP request found. Please request a new code.');
      }
      const otpData = snap.data() || {};
      if (otpData.usedAt) {
        throw new HttpsError('failed-precondition', 'OTP already used. Please request a new code.');
      }

      const expiresAt = otpData.expiresAt?.toDate ? otpData.expiresAt.toDate() : null;
      if (!expiresAt || Date.now() > expiresAt.getTime()) {
        throw new HttpsError('deadline-exceeded', 'OTP expired. Please request a new code.');
      }

      const attempts = Number(otpData.attempts || 0);
      if (attempts >= 5) {
        throw new HttpsError('resource-exhausted', 'Too many attempts. Please request a new code.');
      }

      const expectedHash = String(otpData.otpHash || '');
      const salt = String(otpData.salt || '');
      const receivedHash = hashOtp({ email, otp, salt });
      if (!expectedHash || receivedHash !== expectedHash) {
        await ref.set(
          {
            attempts: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        throw new HttpsError('permission-denied', 'Invalid OTP code.');
      }

      // OTP ok: create auth user + Firestore user doc.
      const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: fullName,
      });

      // Generate structured ID for user
      const structuredId = await generateStructuredId(db, 'user');

      await db
        .collection('users')
        .doc(structuredId)
        .set(
          {
            structuredId: structuredId, // New structured ID
            uid: userRecord.uid,         // Firebase Auth UID
            name: fullName,
            firstName,
            lastName,
            email,
            role: 'parishioner',
            status: 'active',
            profileImage: '',
            phone: '',
            address: address || '',
            barangay: barangay || '',
            sex: sex || '',
            birthday: birthday ? admin.firestore.Timestamp.fromDate(birthday) : null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastLogin: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      await ref.set(
        {
          usedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return {
        status: 'ok',
        uid: userRecord.uid,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('verifySignupOtpAndCreateAccount unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', err?.message ? String(err.message) : 'Unknown internal error');
    }
  }
);

exports.notifyBookingPendingEmail = onDocumentCreated(
  {
    region: 'asia-southeast1',
    document: 'bookings/{bookingId}',
    secrets: [SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const bookingId = event.params.bookingId;
    const data = snap.data() || {};

    const status = String(data.status || '').toLowerCase();
    if (status && status !== 'pending') return;

    const to = String(data.userEmail || data.email || '').trim();
    if (!isValidEmail(to)) return;

    const ref = snap.ref;
    const latestBeforeSend = await ref.get();
    const latestBeforeSendData = latestBeforeSend.data() || {};
    const alreadySent = Boolean(latestBeforeSendData?.notifications?.pendingEmailSentAt);
    if (alreadySent) return;

    try {
      await sendBookingStatusEmail({
        to,
        bookingId,
        booking: data,
        statusLabel: 'Pending',
        introLine: 'We received your booking request. Our admin team will review it and you will receive another email once it is confirmed.',
        paidAt: null,
        transactionRef: '',
      });

      await admin.firestore().runTransaction(async (tx) => {
        const latest = await tx.get(ref);
        const latestData = latest.data() || {};
        const sentAlready = Boolean(latestData?.notifications?.pendingEmailSentAt);
        if (sentAlready) return;
        tx.set(
          ref,
          {
            notifications: {
              pendingEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true }
        );
      });

      console.log('notifyBookingPendingEmail sent', { bookingId, to });
    } catch (emailErr) {
      console.error('notifyBookingPendingEmail failed', {
        bookingId,
        to,
        message: emailErr?.message,
        stack: emailErr?.stack,
      });
    }
  }
);

exports.notifyBookingConfirmationEmail = onDocumentUpdated(
  {
    region: 'asia-southeast1',
    document: 'bookings/{bookingId}',
    secrets: [SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const bookingId = event.params.bookingId;
    const beforeData = before.data() || {};
    const afterData = after.data() || {};

    const beforeStatus = String(beforeData.status || '').toLowerCase();
    const afterStatus = String(afterData.status || '').toLowerCase();
    if (beforeStatus === afterStatus) return;
    if (afterStatus !== 'confirmed' && afterStatus !== 'paid') return;

    const to = String(afterData.userEmail || afterData.email || '').trim();
    if (!isValidEmail(to)) return;

    const ref = after.ref;
    const latestBeforeSend = await ref.get();
    const latestBeforeSendData = latestBeforeSend.data() || {};
    const notificationField = afterStatus === 'paid'
      ? 'paymentConfirmationEmailSentAt'
      : 'confirmationEmailSentAt';
    const alreadySent = Boolean(latestBeforeSendData?.notifications?.[notificationField]);
    if (alreadySent) return;

    const paidAt = afterData?.xendit?.paidAt?.toDate
      ? afterData.xendit.paidAt.toDate()
      : new Date();
    const transactionRef = String(afterData?.xendit?.invoiceId || bookingId);
    const statusLabel = afterStatus === 'paid' ? 'Paid' : 'Confirmed';
    const introLine = afterStatus === 'paid'
      ? 'Your booking payment has been received. Thank you for completing your reservation.'
      : 'Your booking has been confirmed by Sto. Rosario Parish Church.';

    try {
      await sendBookingStatusEmail({
        to,
        bookingId,
        booking: afterData,
        statusLabel,
        introLine,
        paidAt,
        transactionRef,
      });

      await admin.firestore().runTransaction(async (tx) => {
        const latest = await tx.get(ref);
        const latestData = latest.data() || {};
        const sentAlready = Boolean(latestData?.notifications?.[notificationField]);
        if (sentAlready) return;
        tx.set(
          ref,
          {
            notifications: {
              [notificationField]: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true }
        );
      });

      console.log('notifyBookingConfirmationEmail sent', { bookingId, to });
    } catch (emailErr) {
      console.error('notifyBookingConfirmationEmail failed', {
        bookingId,
        to,
        message: emailErr?.message,
        stack: emailErr?.stack,
      });
    }
  }
);

exports.notifyDonationReceiptEmail = onDocumentUpdated(
  {
    region: 'asia-southeast1',
    document: 'donations/{donationId}',
    secrets: [SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const beforeData = before.data() || {};
    const afterData = after.data() || {};
    const donationId = event.params.donationId;

    const beforeStatus = String(beforeData.status || '').toLowerCase();
    const afterStatus = String(afterData.status || '').toLowerCase();
    if (beforeStatus === 'paid' || afterStatus !== 'paid') return;

    const isAnonymous = Boolean(afterData.isAnonymous);
    const to = String(afterData.email || afterData.userEmail || '').trim();
    
    // For anonymous donations, only send if email is provided (optional receipt)
    // For non-anonymous, always try to send to the user's email
    if (!isValidEmail(to)) return;

    const ref = after.ref;
    const latestBeforeSend = await ref.get();
    const latestBeforeSendData = latestBeforeSend.data() || {};
    const alreadySent = Boolean(latestBeforeSendData?.notifications?.receiptEmailSentAt);
    if (alreadySent) return;

    const donorName = String(afterData.name || afterData.userName || 'Donor');
    const amount = Number(afterData.amount || 0);
    const referenceId = String(afterData?.xendit?.invoiceId || donationId);
    const paidAt = afterData?.xendit?.paidAt?.toDate
      ? afterData.xendit.paidAt.toDate()
      : new Date();

    try {
      await sendReceiptEmail({
        to,
        donorName,
        amount,
        referenceId,
        paidAt,
      });

      await admin.firestore().runTransaction(async (tx) => {
        const latest = await tx.get(ref);
        const latestData = latest.data() || {};
        const sentAlready = Boolean(latestData?.notifications?.receiptEmailSentAt);
        if (sentAlready) return;
        tx.set(
          ref,
          {
            notifications: {
              receiptEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true }
        );
      });

      console.log('notifyDonationReceiptEmail sent', { donationId, to });
    } catch (emailErr) {
      console.error('notifyDonationReceiptEmail failed', {
        donationId,
        to,
        message: emailErr?.message,
        stack: emailErr?.stack,
      });
    }
  }
);

exports.notifyMassOfferingReceiptEmail = onDocumentUpdated(
  {
    region: 'asia-southeast1',
    document: 'mass_offerings/{offeringId}',
    secrets: [SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    if (!before || !after) return;

    const beforeData = before.data() || {};
    const afterData = after.data() || {};
    const offeringId = event.params.offeringId;

    const beforeStatus = String(beforeData.status || '').toLowerCase();
    const afterStatus = String(afterData.status || '').toLowerCase();
    if (beforeStatus === 'paid' || afterStatus !== 'paid') return;

    const isAnonymous = Boolean(afterData.isAnonymous);
    const to = String(afterData.email || afterData.userEmail || '').trim();
    
    // For anonymous offerings, only send if email is provided (optional receipt)
    // For non-anonymous, always try to send to the user's email
    if (!isValidEmail(to)) return;

    const ref = after.ref;
    const latestBeforeSend = await ref.get();
    const latestBeforeSendData = latestBeforeSend.data() || {};
    const alreadySent = Boolean(latestBeforeSendData?.notifications?.receiptEmailSentAt);
    if (alreadySent) return;

    const donorName = String(afterData.name || afterData.userName || 'Donor');
    const amount = Number(afterData.amount || 0);
    const referenceId = String(afterData?.xendit?.invoiceId || offeringId);
    const paidAt = afterData?.xendit?.paidAt?.toDate
      ? afterData.xendit.paidAt.toDate()
      : new Date();

    try {
      await sendReceiptEmail({
        to,
        donorName,
        amount,
        referenceId,
        paidAt,
      });

      await admin.firestore().runTransaction(async (tx) => {
        const latest = await tx.get(ref);
        const latestData = latest.data() || {};
        const sentAlready = Boolean(latestData?.notifications?.receiptEmailSentAt);
        if (sentAlready) return;
        tx.set(
          ref,
          {
            notifications: {
              receiptEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true }
        );
      });

      console.log('notifyMassOfferingReceiptEmail sent', { offeringId, to });
    } catch (emailErr) {
      console.error('notifyMassOfferingReceiptEmail failed', {
        offeringId,
        to,
        message: emailErr?.message,
        stack: emailErr?.stack,
      });
    }
  }
);

exports.createXenditBookingInvoice = onCall(
  {
    region: 'asia-southeast1',
    secrets: [XENDIT_SECRET_KEY, SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (request) => {
    try {
      const data = request.data || {};

      // Normalize fields to accept both canonical and alias fields
      const normalizedData = normalizeFields(data, 'booking');
      if (!normalizedData.sacramentType && normalizedData.details && typeof normalizedData.details === 'object') {
        const fields = normalizedData.details.fields;
        if (fields && typeof fields === 'object') {
          const candidate = String(fields['Sacrament Type'] || fields.sacramentType || fields.sacrament || fields.type || fields['Sacrament'] || '').trim();
          if (candidate.length > 0) {
            normalizedData.sacramentType = candidate;
          }
        }
      }

      if ((!normalizedData.userName || typeof normalizedData.userName !== 'string' || normalizedData.userName.trim().length === 0) && request.auth?.token?.name) {
        normalizedData.userName = String(request.auth.token.name).trim();
      }
      if ((!normalizedData.userEmail || typeof normalizedData.userEmail !== 'string' || normalizedData.userEmail.trim().length === 0) && request.auth?.token?.email) {
        normalizedData.userEmail = String(request.auth.token.email).trim();
      }
      
      // Validate required canonical fields
      const validationErrors = validateCanonicalFields(normalizedData, 'booking');
      if (validationErrors.length > 0) {
        throw new HttpsError('invalid-argument', `Validation failed: ${validationErrors.join(', ')}`);
      }

      const sacramentType = requireNonEmptyString(normalizedData.sacramentType, 'sacramentType');
      let amountNumber = Number(normalizedData.amount);
      if (!Number.isFinite(amountNumber) || amountNumber <= 0) {
        throw new HttpsError('invalid-argument', 'Amount must be a number greater than zero.');
      }

      const details = normalizedData.details && typeof normalizedData.details === 'object' ? normalizedData.details : {};
      const feeBreakdown = normalizedData.feeBreakdown && typeof normalizedData.feeBreakdown === 'object' ? normalizedData.feeBreakdown : {};

      const uid = request.auth?.uid || '';
      const userName = request.auth?.token?.name || '';
      const userEmail = request.auth?.token?.email || '';

      const db = admin.firestore();
      const providedBookingId = normalizedData.bookingId && typeof normalizedData.bookingId === 'string'
        ? String(normalizedData.bookingId).trim()
        : '';

      let bookingRef;
      let structuredId = providedBookingId;
      if (providedBookingId) {
        bookingRef = db.collection('bookings').doc(providedBookingId);
      } else {
        structuredId = await generateStructuredId(db, 'booking');
        bookingRef = db.collection('bookings').doc(structuredId);
      }

      const existingBooking = await bookingRef.get();
      if (existingBooking.exists) {
        const existingData = existingBooking.data() || {};
        const existingStatus = String(existingData.status || '').toLowerCase();
        const existingXenditStatus = String(existingData?.xendit?.status || '').toLowerCase();
        const isAlreadyPaid =
          existingStatus === 'paid' ||
          existingXenditStatus === 'paid' ||
          existingXenditStatus === 'settled';

        if (isAlreadyPaid) {
          await maybeSendBookingAlreadyPaidEmail({ bookingRef, bookingData: existingData });
          return {
            bookingId: bookingRef.id,
            alreadyPaid: true,
            checkoutUrl: String(existingData?.xendit?.invoiceUrl || ''),
          };
        }

        if (existingData.xendit && existingData.xendit.invoiceUrl) {
          return {
            bookingId: bookingRef.id,
            checkoutUrl: String(existingData.xendit.invoiceUrl || ''),
          };
        }
      }

      const fields = (details && details.fields) || {};
      const canonicalType = canonicalSacramentType(sacramentType) || '';
      const rowDate = extractScheduleDateStringFromFields(fields, canonicalType);
      const rowTime = extractScheduleTimeStringFromFields(fields, canonicalType);
      if (canonicalType === 'baptism') {
        amountNumber = baptismFeeForDate(rowDate || existingBooking.data()?.date || '');
        feeBreakdown.total = amountNumber;
        feeBreakdown.currency = 'PHP';
        feeBreakdown.rate = baptismFeeLabelForDate(rowDate || existingBooking.data()?.date || '');
      }

      // SCHEDULING CONFLICT CHECK
      // Only check conflicts for new bookings (not updates)
      if (!providedBookingId) {
        if (isMassIntention(canonicalType)) {
          if (!rowDate || !rowTime || rowTime.trim().length === 0) {
            throw new HttpsError(
              'invalid-argument',
              'Mass Intention requires both date and time to be specified.'
            );
          }

          const isValidMassSchedule = await validateMassIntentionSchedule(
            db,
            rowDate,
            rowTime
          );

          if (!isValidMassSchedule) {
            throw new HttpsError(
              'invalid-argument',
              'The selected date and time does not match any official Mass schedule. Please select a valid Mass schedule.'
            );
          }
        } else if (isRestrictedService(canonicalType)) {
          if (!rowDate || !rowTime || rowTime.trim().length === 0) {
            throw new HttpsError(
              'invalid-argument',
              'A valid date and time are required before booking this service.'
            );
          }

          const conflictResult = await checkSchedulingConflict(
            db,
            rowDate,
            rowTime,
            canonicalType,
            null
          );

        if (conflictResult) {
          const conflictMsg =
            `${conflictResult.message || 'The selected date and time conflicts with another approved booking.'} ` +
            `(Booking ID: ${conflictResult.conflictingBookingId}, ` +
            `Service: ${conflictResult.conflictingSacramentType}, ` +
            `Booked by: ${conflictResult.conflictingUserName})`;
            throw new HttpsError('conflict', conflictMsg);
          }
        }
      }

      // Prepare booking data - check if we should set status
      const bookingData = {
        structuredId: structuredId,
        userId: uid,
        userName,
        userEmail,
        sacramentType,
        sacramentTypeKey: canonicalType,
        date: rowDate || '',
        time: rowTime || '',
        details,
        feeBreakdown,
        amount: amountNumber,
        currency: 'PHP',
        paymentMethod: 'xendit',
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        assignedPriest: '',
        adminNotes: '',
      };

      // Store add-ons separately if present
      if (feeBreakdown.addons && Array.isArray(feeBreakdown.addons) && feeBreakdown.addons.length > 0) {
        bookingData.weddingAddons = feeBreakdown.addons;
        bookingData.weddingAddonsTotal = feeBreakdown.addons.reduce((sum, addon) => sum + (addon.price || 0), 0);
      }

      // Only set status to 'pending' if not already paid
      // Preserve existing status if it's already been updated by the webhook
      if (existingBooking.exists) {
        const existingData = existingBooking.data() || {};
        const existingStatus = String(existingData.status || '').toLowerCase();
        if (existingStatus !== 'paid') {
          bookingData.status = 'pending';
        }
      } else {
        bookingData.status = 'pending';
      }

      // Build invoice description including add-ons if present
      let invoiceDescription = `Booking - ${sacramentType} - Sto. Rosario Parish Church`;
      if (feeBreakdown.addons && Array.isArray(feeBreakdown.addons) && feeBreakdown.addons.length > 0) {
        const addonNames = feeBreakdown.addons.map(addon => addon.name).join(', ');
        invoiceDescription += ` [Add-ons: ${addonNames}]`;
      }

      const invoice = await createXenditInvoice({
        externalId: bookingRef.id,
        amount: amountNumber,
        payerEmail: userEmail,
        description: invoiceDescription,
        customerName: userName,
      });

      const invoiceId = String(invoice?.id || '').trim();
      const invoiceUrl = String(invoice?.invoice_url || '').trim();
      const invoiceStatus = String(invoice?.status || 'PENDING').trim();
      if (!invoiceId || !invoiceUrl) {
        throw new HttpsError('internal', 'Xendit did not return an invoice URL.');
      }

      await bookingRef.set(
        {
          ...bookingData,
          xendit: {
            invoiceId,
            invoiceUrl,
            status: invoiceStatus.toLowerCase(),
          },
          paymentMethod: 'xendit',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        bookingId: bookingRef.id,
        checkoutUrl: invoiceUrl,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('createXenditBookingInvoice unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', err?.message ? String(err.message) : 'Unknown internal error');
    }
  }
);

exports.getBookingAvailability = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    const data = request.data || {};
    const date = String(data.date || '').trim();
    const time = String(data.time || '').trim();
    const sacramentType = String(data.sacramentType || '').trim();

    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      throw new HttpsError('invalid-argument', 'date must be in YYYY-MM-DD format.');
    }

    const requestedMinutes = time ? parseTimeToMinutes(time) : null;
    if (time && requestedMinutes == null) {
      throw new HttpsError('invalid-argument', 'time must be in HH:MM or h:mm AM/PM format.');
    }

    const requestedCanonicalType = canonicalSacramentType(sacramentType);
    const requestedPeriod = requestedMinutes == null ? null : schedulePeriodFromMinutes(requestedMinutes);

    const db = admin.firestore();
    const newSnap = await db
      .collection('bookings')
      .where('date', '==', date)
      .where('status', 'in', ACTIVE_BOOKING_STATUSES)
      .get();
    const oldSnap = await db
      .collection('sacrament_requests')
      .where('status', 'in', ACTIVE_BOOKING_STATUSES)
      .get();

    let matches = 0;
    let overlaps = 0;
    let periodMatches = 0;
    for (const doc of [...newSnap.docs, ...oldSnap.docs]) {
      const row = doc.data() || {};
      const {
        canonicalType: resolvedTypeKey,
        date: rowDate,
        time: rowTime,
      } = bookingScheduleValues(row, requestedCanonicalType);

      if (!resolvedTypeKey || !isRestrictedService(resolvedTypeKey)) {
        continue;
      }
      if (!rowDate || rowDate !== date) continue;

      if (time) {
        if (!rowTime) continue;
        const rowMinutes = parseTimeToMinutes(rowTime);
        if (rowMinutes == null) continue;
        if (Math.abs(rowMinutes - requestedMinutes) < 60) overlaps += 1;
        if (
          resolvedTypeKey === requestedCanonicalType &&
          schedulePeriodFromMinutes(rowMinutes) === requestedPeriod
        ) {
          periodMatches += 1;
        }
      }

      if (!requestedCanonicalType || resolvedTypeKey === requestedCanonicalType) {
        matches += 1;
      }
    }

    const capacity = time ? 1 : 2;
    let status = 'available';
    if (time && (overlaps > 0 || periodMatches > 0)) status = 'fully_booked';
    else if (!time && matches >= capacity) status = 'fully_booked';
    else if (matches > 0) status = 'limited';

    // Privacy: return aggregate info only.
    return {
      date,
      time: time || null,
      sacramentType: sacramentType || null,
      status,
      bookedCount: matches,
      capacity,
      overlapCount: overlaps,
      periodBookedCount: periodMatches,
    };
  }
);

const PARISH_ASSISTANT_CONTEXT = `You are the AI assistant for Sto. Rosario Parish Church.
Answer only parish-related questions using facts in the supplied database context. Do not use general knowledge, infer missing facts, or answer unrelated questions. If the requested fact is not in the database context, clearly say that no official database record is available.

Privacy rules:
- Never reveal private names, emails, phone numbers, addresses, payment methods, document links, health details, or specific booking owner details.
- For bookings and donations, answer with aggregate status or the signed-in user's own summarized records only.
- If a user asks for another person's records or confidential details, politely refuse.
- Match the user's language. Use Tagalog for Tagalog questions and English for English questions.
- Fees, requirements, and schedules must come from the whitelisted real-time database context only. Never estimate prices or invent missing requirements.`;

function isParishAssistantTopic(message) {
  return /(parish|church|sto\.?\s*rosario|apo\s*sayong|misa|mass|binyag|baptism|kumpil|confirmation|kasal|wedding|funeral|yumao|house\s*blessing|basbas|anointing|communion|komunyon|sakramento|sacrament|booking|reserve|reservation|schedule|iskedyul|available|availability|slot|fee|bayad|price|requirement|rekisito|document|dokumento|donation|abuloy|alay|announcement|anunsyo|parish priest|pari|contact|address|location|office hours)/i.test(String(message || ''));
}

function parishScopeReply(language) {
  return language === 'tagalog'
    ? 'Makakasagot lamang ako tungkol sa Sto. Rosario Parish at sa opisyal na impormasyong naka-record sa parish database—halimbawa, mga schedule, serbisyo, requirements, fee, booking, at anunsyo.'
    : 'I can only help with Sto. Rosario Parish and official information recorded in the parish database, such as schedules, services, requirements, fees, bookings, and announcements.';
}

function detectAssistantLanguage(text) {
  const lower = String(text || '').toLowerCase();
  const tagalogWords = [
    'ano', 'alin', 'bakit', 'paano', 'saan', 'kailan', 'sino', 'magkano',
    'misa', 'binyag', 'kumpil', 'kasal', 'basbas', 'yumao', 'intensyon',
    'sakramento', 'parokya', 'simbahan', 'pari', 'pwede', 'puwede',
    'kailangan', 'gusto', 'salamat',
  ];
  const matches = tagalogWords.filter((word) => new RegExp(`\\b${word}\\b`, 'i').test(lower)).length;
  return matches >= 2 ? 'tagalog' : 'english';
}

function extractAssistantDate(text) {
  const match = String(text || '').match(/\b(\d{4}-\d{2}-\d{2})\b/);
  return match ? match[1] : '';
}

function extractAssistantTime(text) {
  const match = String(text || '').match(/\b(\d{1,2}(?::\d{2})?\s*(?:[AaPp][Mm])?)\b/);
  return match ? match[1].trim() : '';
}

function extractAssistantSacrament(text) {
  const canonical = canonicalSacramentType(text);
  const names = {
    baptism: 'Baptism',
    confirmation: 'Confirmation',
    wedding: 'Wedding',
    funeral: 'Funeral Mass',
    house_blessing: 'House Blessing',
    anointing: 'Anointing of the Sick',
    first_communion: 'First Communion',
    mass_intention: 'Mass Intentions',
  };
  return names[canonical] || '';
}

function detectAssistantIntent(text) {
  const lower = String(text || '').toLowerCase();
  const intents = new Set(['general']);

  if (/(available|availability|slot|schedule|book|booking|reserve|conflict|bakante|iskedyul|petsa|oras)/i.test(lower)) {
    intents.add('availability');
  }
  if (/(fee|fees|price|cost|amount|payment|how much|magkano|bayad|presyo|halaga)/i.test(lower)) {
    intents.add('fees');
    intents.add('service_facts');
  }
  if (/(requirement|requirements|document|documents|kailangan|rekisito|requirements|dokumento)/i.test(lower)) {
    intents.add('requirements');
    intents.add('service_facts');
  }
  if (/(sacrament|service|baptism|binyag|wedding|kasal|confirmation|kumpil|funeral|yumao|house blessing|basbas|anointing|pagpapahid|communion|komunyon)/i.test(lower)) {
    intents.add('service_facts');
  }
  if (/(mass|misa|service|sunday|daily)/i.test(lower)) intents.add('mass_schedule');
  if (/(announcement|event|fiesta|thanksgiving|holy week|anunsyo|kaganapan)/i.test(lower)) intents.add('announcements');
  if (/(donat|donation|alay|abuloy|bigay|in-kind)/i.test(lower)) intents.add('donations');
  if (/(my booking|my reservation|aking booking|booking ko|requests ko)/i.test(lower)) intents.add('my_bookings');
  if (/(contact|phone|email|address|location|saan|lokasyon|numero)/i.test(lower)) intents.add('contact');

  return Array.from(intents);
}

const SERVICE_FACT_COLLECTIONS = [
  'booking_forms',
  'sacramentServices',
  'churchServices',
  'serviceFees',
  'sacramentFees',
  'services',
  'sacrament_configs',
];

const PUBLIC_SERVICE_FACT_KEYS = new Set([
  'id',
  'name',
  'formName',
  'title',
  'label',
  'displayNames',
  'type',
  'service',
  'serviceName',
  'sacrament',
  'sacramentType',
  'sacramentTypeKey',
  'description',
  'descriptions',
  'fee',
  'fees',
  'amount',
  'price',
  'cost',
  'currency',
  'baseFee',
  'regularFee',
  'weekdayFee',
  'sundayFee',
  'weddingFee',
  'baptismFee',
  'donation',
  'requirements',
  'requiredDocuments',
  'documents',
  'schedule',
  'schedules',
  'massSchedule',
  'officeHours',
  'availableDays',
  'availableTimes',
  'notes',
  'reminders',
  'active',
  'status',
  'updatedAt',
  'lastUpdated',
]);

function sanitizePublicValue(value, depth = 0) {
  if (value == null) return null;
  if (depth > 3) return '[nested data omitted]';
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return value;
  if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.slice(0, 20).map((item) => sanitizePublicValue(item, depth + 1));
  if (typeof value === 'object') {
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      if (PUBLIC_SERVICE_FACT_KEYS.has(key) || /fee|price|cost|amount|require|document|schedule|time|day|note|description/i.test(key)) {
        out[key] = sanitizePublicValue(item, depth + 1);
      }
    }
    return out;
  }
  return null;
}

function compactPublicServiceDoc(doc, collectionName) {
  const data = doc.data() || {};
  const out = {
    id: doc.id,
    sourceCollection: collectionName,
  };
  for (const [key, value] of Object.entries(data)) {
    if (PUBLIC_SERVICE_FACT_KEYS.has(key) || /fee|price|cost|amount|require|document|schedule|time|day|note|description/i.test(key)) {
      out[key] = sanitizePublicValue(value);
    }
  }
  return out;
}

function compactPublicServiceMap(key, value, source) {
  if (value == null) return null;
  const base = {
    id: key,
    sourceCollection: source,
  };
  if (typeof value === 'object' && !Array.isArray(value)) {
    return { ...base, ...sanitizePublicValue(value) };
  }
  return { ...base, value: sanitizePublicValue(value) };
}

function serviceFactMatches(message, serviceFact) {
  const lower = String(message || '').toLowerCase();
  const canonical = canonicalSacramentType(lower);
  if (!canonical) return true;

  const haystack = JSON.stringify(serviceFact || {}).toLowerCase();
  if (haystack.includes(canonical)) return true;

  const aliases = {
    baptism: ['baptism', 'binyag'],
    confirmation: ['confirmation', 'kumpil'],
    wedding: ['wedding', 'kasal', 'marriage'],
    funeral: ['funeral', 'yumao'],
    house_blessing: ['house blessing', 'house_blessing', 'basbas'],
    anointing: ['anointing', 'pagpapahid'],
    first_communion: ['first communion', 'first_communion', 'komunyon'],
    mass_intention: ['mass intention', 'mass_intention', 'intensyon'],
  };
  return (aliases[canonical] || []).some((alias) => haystack.includes(alias));
}

function collectFeeFacts(serviceFacts) {
  const feeKeyPattern = /fee|price|cost|amount|donation|bayad|presyo/i;
  const rows = [];

  function walk(value, path, row) {
    if (value == null) return;
    if (typeof value === 'number' || typeof value === 'string') {
      if (feeKeyPattern.test(path)) {
        row.fees.push({ field: path, value });
      }
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((item, index) => walk(item, `${path}[${index}]`, row));
      return;
    }
    if (typeof value === 'object') {
      Object.entries(value).forEach(([key, item]) => walk(item, path ? `${path}.${key}` : key, row));
    }
  }

  serviceFacts.forEach((fact) => {
    const row = {
      service: fact.formName || fact.name || fact.title || fact.serviceName || fact.sacramentType || fact.sacramentTypeKey || fact.id,
      source: fact.sourceCollection,
      fees: [],
    };
    walk(fact, '', row);
    if (row.fees.length > 0) rows.push(row);
  });

  return rows;
}

function collectRequirementFacts(serviceFacts) {
  const requirementKeyPattern = /require|document|dokumento|rekisito/i;
  const rows = [];

  function walk(value, path, row) {
    if (value == null) return;
    if (typeof value === 'string') {
      if (requirementKeyPattern.test(path)) row.requirements.push(value);
      return;
    }
    if (Array.isArray(value)) {
      if (requirementKeyPattern.test(path)) {
        row.requirements.push(...value.map((item) => sanitizePublicValue(item)).filter((item) => item != null));
        return;
      }
      value.forEach((item, index) => walk(item, `${path}[${index}]`, row));
      return;
    }
    if (typeof value === 'object') {
      Object.entries(value).forEach(([key, item]) => walk(item, path ? `${path}.${key}` : key, row));
    }
  }

  serviceFacts.forEach((fact) => {
    const row = {
      service: fact.formName || fact.name || fact.title || fact.serviceName || fact.sacramentType || fact.sacramentTypeKey || fact.id,
      source: fact.sourceCollection,
      requirements: [],
    };
    walk(fact, '', row);
    if (row.requirements.length > 0) rows.push(row);
  });

  return rows;
}

function formatFactValue(value) {
  if (typeof value === 'number') return formatPhp(value);
  if (typeof value === 'string') {
    const numeric = Number(value.replace(/[^\d.]/g, ''));
    if (/^\s*(php|p)?\s*[\d,]+(\.\d+)?\s*$/i.test(value) && Number.isFinite(numeric)) {
      return formatPhp(numeric);
    }
    return value;
  }
  return JSON.stringify(value);
}

function directServiceFactAnswer(language, intents, serviceFacts) {
  const wantsFees = intents.includes('fees');
  const wantsRequirements = intents.includes('requirements');
  if (!wantsFees && !wantsRequirements) return '';

  if (!serviceFacts.length) {
    return language === 'tagalog'
      ? 'Wala pa akong nakitang opisyal na fee o requirement record sa database para sa tanong na ito. Para maiwasan ang maling sagot, hindi ako magbibigay ng tantya.'
      : 'I could not find an official fee or requirement record in the database for that question. To avoid giving incorrect information, I will not estimate it.';
  }

  const lines = [];
  if (wantsFees) {
    const feeRows = collectFeeFacts(serviceFacts);
    if (!feeRows.length) {
      lines.push(language === 'tagalog'
        ? 'Walang fee field na naka-record sa database para sa serbisyong iyon.'
        : 'No fee field is recorded in the database for that service.');
    } else {
      feeRows.forEach((row) => {
        const values = row.fees.map((fee) => `${fee.field}: ${formatFactValue(fee.value)}`).join(', ');
        lines.push(`${row.service}: ${values}`);
      });
    }
  }

  if (wantsRequirements) {
    const requirementRows = collectRequirementFacts(serviceFacts);
    if (!requirementRows.length) {
      lines.push(language === 'tagalog'
        ? 'Walang requirement field na naka-record sa database para sa serbisyong iyon.'
        : 'No requirement field is recorded in the database for that service.');
    } else {
      requirementRows.forEach((row) => {
        const values = row.requirements.map((item) => typeof item === 'string' ? item : JSON.stringify(item)).join('; ');
        lines.push(`${row.service}: ${values}`);
      });
    }
  }

  return language === 'tagalog'
    ? `Batay sa kasalukuyang database record: ${lines.join(' ')}`
    : `Based on the current database record: ${lines.join(' ')}`;
}

function publicBookingSummary(doc) {
  const row = doc.data() || {};
  const values = bookingScheduleValues(row, canonicalSacramentType(row.sacramentType));
  return {
    sacramentType: row.sacramentType || values.canonicalType || 'Sacrament',
    date: values.date || null,
    time: values.time || null,
    status: row.status || null,
  };
}

async function getPublicParishSnapshot(db, intents, message) {
  const snapshot = {
    parishProfile: null,
    serviceFacts: [],
    massSchedules: [],
    announcements: [],
    availability: null,
    donationSummary: null,
  };

  try {
    const profileSnap = await db.collection('parish_profile').limit(1).get();
    if (!profileSnap.empty) {
      const profile = profileSnap.docs[0].data() || {};
      snapshot.parishProfile = {
        name: profile.name || profile.parishName || null,
        address: profile.address || profile.location || null,
        phone: profile.phone || profile.contactNumber || null,
        email: profile.email || null,
        officeHours: profile.officeHours || null,
      };

      const profileFactFields = ['sacraments', 'services', 'serviceFees', 'sacramentFees', 'fees', 'requirements'];
      for (const field of profileFactFields) {
        const value = profile[field];
        if (Array.isArray(value)) {
          value.forEach((item, index) => {
            const fact = compactPublicServiceMap(`${field}_${index}`, item, `parish_profile.${field}`);
            if (fact && serviceFactMatches(message, fact)) snapshot.serviceFacts.push(fact);
          });
        } else if (value && typeof value === 'object') {
          Object.entries(value).forEach(([key, item]) => {
            const fact = compactPublicServiceMap(key, item, `parish_profile.${field}`);
            if (fact && serviceFactMatches(message, fact)) snapshot.serviceFacts.push(fact);
          });
        }
      }
    }
  } catch (err) {
    console.warn('askParishAssistant: parish profile read failed', err?.message);
  }

  if (intents.includes('service_facts')) {
    for (const collectionName of SERVICE_FACT_COLLECTIONS) {
      try {
        const snap = await db.collection(collectionName).limit(50).get();
        snap.docs.forEach((doc) => {
          const fact = compactPublicServiceDoc(doc, collectionName);
          if (serviceFactMatches(message, fact)) snapshot.serviceFacts.push(fact);
        });
      } catch (err) {
        console.warn(`askParishAssistant: ${collectionName} read failed`, err?.message);
      }
    }
    snapshot.serviceFacts = snapshot.serviceFacts.slice(0, 20);
  }

  if (intents.includes('mass_schedule')) {
    try {
      const massSnap = await db.collection('massSchedules').where('active', '==', true).limit(20).get();
      snapshot.massSchedules = massSnap.docs.map((doc) => {
        const row = doc.data() || {};
        return {
          dayOfWeek: row.dayOfWeek || null,
          date: row.date || null,
          startTime: row.startTime || row.time || null,
          endTime: row.endTime || null,
        };
      });
    } catch (err) {
      console.warn('askParishAssistant: mass schedule read failed', err?.message);
    }
  }

  if (intents.includes('announcements')) {
    try {
      const announcementSnap = await db.collection('announcements').orderBy('createdAt', 'desc').limit(5).get();
      snapshot.announcements = announcementSnap.docs.map((doc) => {
        const row = doc.data() || {};
        return {
          title: row.title || null,
          date: row.date || null,
          summary: row.summary || row.description || row.content || null,
        };
      });
    } catch (err) {
      console.warn('askParishAssistant: announcements read failed', err?.message);
    }
  }

  if (intents.includes('donations')) {
    try {
      const donationSnap = await db.collection('donations').limit(50).get();
      const counts = {};
      donationSnap.docs.forEach((doc) => {
        const type = String(doc.data()?.donationType || 'unknown');
        counts[type] = (counts[type] || 0) + 1;
      });
      snapshot.donationSummary = { recentSampleSize: donationSnap.size, countsByType: counts };
    } catch (err) {
      console.warn('askParishAssistant: donation summary read failed', err?.message);
    }
  }

  if (intents.includes('availability')) {
    const date = extractAssistantDate(message);
    const time = extractAssistantTime(message);
    const sacramentType = extractAssistantSacrament(message);

    if (date) {
      const requestedMinutes = time ? parseTimeToMinutes(time) : null;
      if (time && requestedMinutes == null) {
        throw new HttpsError('invalid-argument', 'time must be in HH:MM or h:mm AM/PM format.');
      }

      const requestedCanonicalType = canonicalSacramentType(sacramentType);
      const requestedPeriod = requestedMinutes == null ? null : schedulePeriodFromMinutes(requestedMinutes);
      const newSnap = await db
        .collection('bookings')
        .where('date', '==', date)
        .where('status', 'in', ACTIVE_BOOKING_STATUSES)
        .get();
      const oldSnap = await db
        .collection('sacrament_requests')
        .where('status', 'in', ACTIVE_BOOKING_STATUSES)
        .get();

      let matches = 0;
      let overlaps = 0;
      let periodMatches = 0;
      for (const doc of [...newSnap.docs, ...oldSnap.docs]) {
        const row = doc.data() || {};
        const {
          canonicalType: resolvedTypeKey,
          date: rowDate,
          time: rowTime,
        } = bookingScheduleValues(row, requestedCanonicalType);

        if (!resolvedTypeKey || !isRestrictedService(resolvedTypeKey)) continue;
        if (rowDate !== date) continue;

        if (time) {
          const rowMinutes = parseTimeToMinutes(String(rowTime || ''));
          if (rowMinutes == null) continue;
          if (Math.abs(rowMinutes - requestedMinutes) < 60) overlaps += 1;
          if (resolvedTypeKey === requestedCanonicalType && schedulePeriodFromMinutes(rowMinutes) === requestedPeriod) {
            periodMatches += 1;
          }
        }

        if (!requestedCanonicalType || resolvedTypeKey === requestedCanonicalType) matches += 1;
      }

      const capacity = time ? 1 : 2;
      let status = 'available';
      if (time && (overlaps > 0 || periodMatches > 0)) status = 'fully_booked';
      else if (!time && matches >= capacity) status = 'fully_booked';
      else if (matches > 0) status = 'limited';

      snapshot.availability = {
        date,
        time: time || null,
        sacramentType: sacramentType || null,
        status,
        bookedCount: matches,
        capacity,
      };
    } else {
      snapshot.availability = { needsDate: true, sacramentType: sacramentType || null };
    }
  }

  return snapshot;
}

async function getUserScopedSnapshot(db, uid, intents) {
  if (!uid || !intents.includes('my_bookings')) return { myBookings: [] };

  const bookingSnap = await db
    .collection('bookings')
    .where('userId', '==', uid)
    .limit(10)
    .get();

  return {
    myBookings: bookingSnap.docs.map(publicBookingSummary),
  };
}

exports.askParishAssistant = onCall(
  {
    region: 'asia-southeast1',
    secrets: [GROQ_API_KEY],
  },
  async (request) => {
    const message = requireBoundedString(request.data?.message, 'message', 1200);
    const rawHistory = Array.isArray(request.data?.history) ? request.data.history.slice(-8) : [];
    const language = detectAssistantLanguage(message);
    const intents = detectAssistantIntent(message);

    if (!isParishAssistantTopic(message)) {
      return {
        reply: parishScopeReply(language),
        intents,
        usedRealtimeData: false,
        answeredFromDatabase: false,
      };
    }

    const db = admin.firestore();

    const publicData = await getPublicParishSnapshot(db, intents, message);
    const userData = await getUserScopedSnapshot(db, request.auth?.uid || '', intents);
    const directAnswer = directServiceFactAnswer(language, intents, publicData.serviceFacts || []);
    if (directAnswer) {
      return {
        reply: directAnswer,
        intents,
        usedRealtimeData: true,
        answeredFromDatabase: true,
      };
    }

    const safeHistory = rawHistory
      .filter((item) => item && (item.role === 'user' || item.role === 'assistant') && typeof item.content === 'string')
      .map((item) => ({
        role: item.role,
        content: item.content.slice(0, 1000),
      }));

    const systemPrompt = `${PARISH_ASSISTANT_CONTEXT}

Detected language: ${language}
Detected intents: ${intents.join(', ')}
Authenticated user: ${request.auth?.uid ? 'yes' : 'no'}

Whitelisted real-time database context:
${JSON.stringify({ publicData, userData }, null, 2)}

Answer naturally and concisely. Cite only facts found in the supplied database context. Never answer from general knowledge or from the conversation history. Do not mention implementation details, APIs, JSON, Firestore, or database internals unless the user asks technical support staff questions.`;

    const apiKey = (GROQ_API_KEY.value() || process.env.GROQ_API_KEY || '').trim();
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'AI service is not configured. Please set the GROQ_API_KEY secret.');
    }

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: GROQ_CHAT_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          ...safeHistory,
          { role: 'user', content: message },
        ],
        temperature: 0.2,
        stream: false,
      }),
      timeout: 20000,
    });

    const bodyText = await response.text();
    if (!response.ok) {
      console.error('askParishAssistant: Groq error', {
        status: response.status,
        body: bodyText.slice(0, 500),
      });
      throw new HttpsError('unavailable', 'The AI service is temporarily unavailable. Please try again later.');
    }

    let body;
    try {
      body = JSON.parse(bodyText);
    } catch (err) {
      console.error('askParishAssistant: invalid Groq JSON', err?.message);
      throw new HttpsError('internal', 'The AI service returned an invalid response.');
    }

    const reply = String(body?.choices?.[0]?.message?.content || '').trim();
    if (!reply) {
      throw new HttpsError('internal', 'The AI service returned an empty response.');
    }

    return {
      reply,
      intents,
      usedRealtimeData: true,
    };
  }
);

const DEFAULT_BOOKING_FORMS = {
  baptism: {
    formKey: 'baptism',
    sacramentTypeKey: 'baptism',
    formName: 'Binyag Form',
    displayNames: { english: 'Baptism', tagalog: 'Binyag' },
    descriptions: {
      english: 'Baptism is the first sacrament of Christian initiation. It gives new life in Christ, frees the person from original sin, and welcomes them as a member of the Church.',
      tagalog: 'Ang binyag ay ang unang sakramento ng pagiging Kristiyano. Ito ang nagbibigay ng bagong buhay kay Kristo, nag-aalis ng orihinal na kasalanan, at tinatanggap ang binyagan bilang kasapi ng Simbahan.',
    },
    fields: [
      'First Name (Pangalan)', 'Middle Name (Gitnang Pangalan)', 'Surname (Apelyido)', 'Suffix (Jr., II, etc.)',
      'Date of Birth (Petsa ng Kapanganakan)', 'Age (Edad)', 'Gender (Kasarian)', 'Place of Birth (Lugar ng Kapanganakan)',
      'Father First Name (Pangalan ng Ama)', 'Father Middle Name (Gitnang Pangalan)', 'Father Surname (Apelyido)', 'Father Suffix (Jr., II, etc.)',
      'Father Place of Birth (Lugar ng Kapanganakan)', 'Father Current Address (Bayan/Lungsod/Lalawigan)',
      'Mother First Name (Pangalan ng Ina)', 'Mother Maiden Middle Name (Gitnang Pangalan sa Pagkadalaga)', 'Mother Maiden Surname (Apelyido sa Pagkadalaga)', 'Mother Place of Birth (Lugar ng Kapanganakan)',
      'Marriage Status', 'Place of Marriage (Lugar ng Kasal)', 'Date of Marriage (Petsa ng Kasal)',
      'Minister of Baptism (Nagbinyag)', 'Date of Baptism (Petsa ng Binyag)', 'Time of Baptism (Oras ng Binyag)',
      'Primary Ninong Name', 'Primary Ninong Age (18 pataas)', 'Primary Ninong Address (Bayan/Lungsod/Lalawigan)',
      'Primary Ninang Name', 'Primary Ninang Age (18 pataas)', 'Primary Ninang Address (Bayan/Lungsod/Lalawigan)',
      'Accomplished by (Nagrala)', 'Relation to Baptized (Kaugnayan)', 'Contact Number (Numero)', 'Date Accomplished (Petsa ng Pagpapatala)',
      'Donation / AR Number', 'Birth Certificate Registry No.', 'Baptism Book No.', 'Page', 'Line', 'Noted by (Tumanggap ng Pagpapatala)',
    ],
    requirements: ['Birth Certificate (PSA)'],
    fees: { currency: 'PHP', sunday: 300, weekday: 1650 },
    schedules: { dateFieldKeys: ['Registration - Date of Baptism', 'Date of Baptism (Petsa ng Binyag)', 'Date of Baptism'], timeFieldKeys: ['Registration - Time of Baptism', 'Time of Baptism (Oras ng Binyag)', 'Time of Baptism'] },
    reminders: {
      english: [
        'Baptism Fee - Weekdays: PHP 1,650 (includes cloths for child and candle) | Sunday after Mass: PHP 300',
        'If parents are below 18 years old, booking cannot proceed online. They must personally coordinate with the parish office.',
      ],
      tagalog: [
        'Bayad sa Binyag - Weekdays: PHP 1,650 (kasama ang damit ng bata at kandila) | Sunday pagkatapos ng Misa: PHP 300',
        'Kung ang mga magulang ay wala pa sa 18 taong gulang, hindi makakapag-book online. Kailangan nilang makipag-ugnayan sa parish office.',
      ],
    },
    active: true,
  },
  confirmation: {
    formKey: 'confirmation',
    sacramentTypeKey: 'confirmation',
    formName: 'Kumpil Form',
    displayNames: { english: 'Confirmation', tagalog: 'Kumpil' },
    descriptions: {
      english: 'Confirmation brings a special outpouring of the Holy Spirit that deepens and strengthens baptismal grace, empowering us to become true witnesses of Christ.',
      tagalog: 'Ang Kumpil ay nagbibigay ng espesyal na pagbubuhos ng Espiritu Santo na mas lalong nagpapatatag at nagpapatibay sa ating binyag upang maging mga saksi ni Kristo.',
    },
    fields: [
      'Date of Confirmation (Petsa ng Kumpil)', 'Day (Araw)', 'Time (Oras)', 'Full Name (Pangalan ng Kukumpilan)', 'Age (Edad)',
      'Gender (Kasarian)', 'Date of Birth (Petsa ng Kapanganakan)', 'Place of Birth (Lugar ng Kapanganakan)', 'Place of Baptism (Saan Nabinyagan)',
      'Date of Baptism (Kailan Nabinyagan)', 'Parish Affiliation (Parokyang Kinabibilangan)', 'Father\'s Name (Ama)',
      'Mother\'s Name (Ina - Apelyido noong dalaga pa)', 'Current Address (Kasalukuyang Tirahan)', 'Contact Number',
      'Ninong Name (Pangalan)', 'Ninong Age (Edad)', 'Ninang Name (Pangalan)', 'Ninang Age (Edad)',
    ],
    requirements: ['Birth Certificate (Sertipiko ng Kapanganakan)', 'Baptismal Certificate (Sertipiko ng Binyag)'],
    fees: { currency: 'PHP', base: 0 },
    schedules: { dateFieldKeys: ['Date of Confirmation (Petsa ng Kumpil)'], timeFieldKeys: ['Time (Oras)'] },
    reminders: {
      english: ['Please upload required documents and other valid files.', 'Ensure all submitted files are complete and clear.'],
      tagalog: ['Mangyaring i-upload ang mga kinakailangang dokumento at iba pang valid files.', 'Siguraduhing kumpleto at malinaw ang lahat ng submitted files.'],
    },
    active: true,
  },
  wedding: {
    formKey: 'wedding',
    sacramentTypeKey: 'wedding',
    formName: 'Kasal Form',
    displayNames: { english: 'Wedding', tagalog: 'Kasal' },
    descriptions: {
      english: 'Holy Matrimony is a sacred covenant between a man and a woman, established by God as a lifelong partnership of love and fidelity.',
      tagalog: 'Ang Kasal ay isang banal na kasunduan sa pagitan ng lalaki at babae, na tinataguyod ng Diyos bilang isang panghabambuhay na pagsasama ng pagmamahalan at katapatan.',
    },
    fields: [
      'Date of Wedding', 'Day', 'Time', 'Groom First Name', 'Groom Middle Name', 'Groom Surname', 'Groom Age', 'Groom Address',
      'Groom Place of Birth', 'Groom Date of Birth', 'Groom Religion', 'Groom Status', 'Groom Father Name', 'Groom Mother Name',
      'Bride First Name', 'Bride Middle Name', 'Bride Surname', 'Bride Age', 'Bride Address', 'Bride Place of Birth',
      'Bride Date of Birth', 'Bride Religion', 'Bride Status', 'Bride Father Name', 'Bride Mother Name', 'Contact Number',
      'Ninong Name', 'Ninong Address', 'Ninang Name', 'Ninang Address',
    ],
    requirements: [
      'Groom Requirements:', '1. Birth Certificate (PSA)', '2. Marriage License/ Marriage Contract', '3. Baptismal Certificate (Marriage Purpose)',
      '4. Confirmation Certificate (Marriage Purpose)', '5. CENOMAR (PSA)', '6. Marriage Banns', '7. 2pcs. 2x2 pictures', '8. Wedding Invitation',
      'Bride Requirements:', '1. Birth Certificate (PSA)', '2. Marriage License/ Marriage Contract', '3. Baptismal Certificate (Marriage Purpose)',
      '4. Confirmation Certificate (Marriage Purpose)', '5. CENOMAR (PSA)', '6. Marriage Banns', '7. 2pcs. 2x2 pictures', '8. Wedding Invitation',
    ],
    fees: { currency: 'PHP', base: 6000 },
    schedules: { dateFieldKeys: ['Date of Wedding'], timeFieldKeys: ['Time'], recommendedSlots: ['10:00 AM', '2:00 PM'] },
    reminders: {
      english: [
        'If either the bride or groom is below 18 years old, the wedding is not allowed.',
        'If the couple is 18 to 20 years old, they must have parental guidance/consent. They are required to coordinate directly with the parish office before proceeding.',
      ],
      tagalog: [
        'Kung ang ikakasal (bride o groom) ay wala pa sa 18 taong gulang, hindi maaaring mag-book ng kasal.',
        'Kung ang ikakasal ay 18 hanggang 20 taong gulang, kinakailangan ng parental guidance/consent. Kailangan nilang makipag-ugnayan sa parish office bago mag-proceed.',
      ],
    },
    active: true,
  },
  funeral: {
    formKey: 'funeral',
    sacramentTypeKey: 'funeral',
    formName: 'Misa para sa Kapayapaan ng Kaluluwa',
    displayNames: { english: 'Funeral Mass', tagalog: 'Misa para sa Yumao' },
    descriptions: {
      english: 'The Funeral Mass is a prayer of the Church offering the soul of the departed to God, asking for His mercy so they may enter eternal life.',
      tagalog: 'Ang Misa para sa Yumao ay isang panalangin ng Simbahan para sa kaluluwa ng namayapa, na humihingi sa awa ng Diyos upang siya ay makapasok sa buhay na walang hanggan.',
    },
    fields: [
      'Full Name (Buong Pangalan ng Namatay)', 'Nickname', 'Age (Edad)', 'Civil Status (Estado)', 'Baptized (Binyagan)',
      'Spouse Name (Pangalan ng Asawa/Maybahay)', 'Number of Children (Bilang ng Anak)', 'Children Status', 'Father\'s Name (Pangalan ng Tatay)',
      'Mother\'s Name (Pangalan ng Nanay)', 'Date of Birth (Petsa ng Kapanganakan)', 'Address (Tirahan)', 'Parish Affiliation (Parokyang Kinabibilangan)',
      'Confession (Kumpisal)', 'Anointing of the Sick (Pagpapahid ng Langis)', 'Viatico', 'Church Service (Naging Lingkod ng Simbahan)',
      'Cause of Death (Sanhi ng Kamatayan)', 'Date of Death (Petsa ng Kamatayan)', 'Place of Death (Lugar ng Kamatayan)',
      'Burial Date (Petsa ng Libing)', 'Burial Day (Araw ng Libing)', 'Burial Time (Oras ng Libing)', 'Burial Place (Lugar ng Libing)',
      'Burial Permit (Meron/Wala)', 'Death Certificate (Meron/Wala)', 'Registered by (Pangalan ng Nagpalista)', 'Relation to Deceased (Kaugnayan)',
      'Contact Number', 'Date Registered (Petsa ng Pagpapatala)', 'Donation / A.R. Number', 'Death Certificate Registry No.',
      'Death Book No.', 'Page', 'Line', 'Presiding Minister (Tagapagdiwang)', 'Received by (Tumanggap ng Pagpapatala)',
    ],
    requirements: ['Burial Permit (Pahintulot sa Libing)', 'Death Certificate (Sertipiko ng Kamatayan)'],
    fees: { currency: 'PHP', base: 0 },
    schedules: { dateFieldKeys: ['Burial Date (Petsa ng Libing)'], timeFieldKeys: ['Burial Time (Oras ng Libing)'] },
    active: true,
  },
  house_blessing: {
    formKey: 'house_blessing',
    sacramentTypeKey: 'house_blessing',
    formName: 'Palista sa House Blessing',
    displayNames: { english: 'House Blessing', tagalog: 'Basbas ng Bahay' },
    descriptions: {
      english: 'House blessing is a prayer asking for God\'s light, guidance, and protection for a home and all who dwell within it.',
      tagalog: 'Ang pagbabasbas ng bahay ay isang panalangin upang hilingin ang gabay at proteksyon ng Diyos para sa tahanan at sa lahat ng naninirahan dito.',
    },
    fields: ['Full Name (Pangalan)', 'Address (Tirahan)', 'Date and Time of Blessing (Petsa at Oras ng Blessing)', 'Phone Number (Cell/Tel. No.)', 'Time Priest Arrival (Oras ng Pagdating ng Pari)'],
    requirements: ['1. Candles with wick base (Kandila - mas mainam na may sapo)', '2. Alms/Donation in bowl (Barya sa mangkok - kung gusto)', '3. Pick up priest at designated time (Sunduin ang pari sa oras na)'],
    fees: { currency: 'PHP', base: 0 },
    schedules: { dateFieldKeys: ['Date and Time of Blessing (Petsa at Oras ng Blessing)'], timeFieldKeys: ['Time Priest Arrival (Oras ng Pagdating ng Pari)'] },
    active: true,
  },
  anointing: {
    formKey: 'anointing',
    sacramentTypeKey: 'anointing',
    formName: 'Palista sa Pagpapahid ng Langis sa May Sakit',
    displayNames: { english: 'Anointing of the Sick', tagalog: 'Pagpapahid sa May Sakit' },
    descriptions: {
      english: 'The Anointing of the Sick confers a special grace providing strength, peace, and courage to endure the difficulties accompanying serious illness or old age.',
      tagalog: 'Ang Pagpapahid sa May Sakit ay nagbibigay ng biyaya ng Espiritu Santo na nagdudulot ng lakas, kapayapaan, at tapang sa mga nakakaranas ng matinding karamdaman.',
    },
    fields: ['Full Name (Pangalan)', 'Age (Edad)', 'Illness/Condition (Sakit)', 'Address (Tirahan)', 'Phone Number (Cell/Tel. No.)', 'Date and Time (Petsa at Oras)'],
    requirements: ['1. Ayusin at linisin ang maysakit (Ensure patient is cleaned and prepared)', '2. Krusipiho at 2 kandila sa basito (Crucifix and 2 candles in container)', '3. Sunduin ang pari sa oras na (Pick up priest at designated time)'],
    fees: { currency: 'PHP', base: 0 },
    schedules: { dateFieldKeys: ['Date and Time (Petsa at Oras)'], timeFieldKeys: ['Date and Time (Petsa at Oras)'] },
    active: true,
  },
  mass_intention: {
    formKey: 'mass_intention',
    sacramentTypeKey: 'mass_intention',
    formName: 'Intensyon ng Misa',
    displayNames: { english: 'Mass Intention', tagalog: 'Intensyon ng Misa' },
    descriptions: {
      english: 'Offering a Mass intention is a way to apply the graces of the Eucharistic sacrifice for specific needs, thanksgiving, or the souls of the faithfully departed.',
      tagalog: 'Ang pag-aalay ng intensyon sa Misa ay ang paglalaan ng mga panalangin ng Simbahan para sa mga partikular na pangangailangan, pasasalamat, o para sa mga kaluluwa ng mga namayapa.',
    },
    fields: ['Full Name of Requestor (Buong Pangalan ng Nag-aalok)', 'Contact Number (Numero ng Telepono)', 'Feast or Name of Intended Person (Kapistahan o Pangalan ng Taong Iaalay)', 'Date of Mass (Petsa ng Misa)', 'Time of Mass (Oras ng Misa)'],
    requirements: ['Form must be filled out clearly (Puno ang form ng malinaw)', 'Donation to be given before mass date (Paghahatid ng donasyon bago ang petsa ng misa)'],
    fees: { currency: 'PHP', base: 0 },
    schedules: { dateFieldKeys: ['Date of Mass (Petsa ng Misa)'], timeFieldKeys: ['Time of Mass (Oras ng Misa)'], usesMassSchedule: true },
    active: true,
  },
  first_communion: {
    formKey: 'first_communion',
    sacramentTypeKey: 'first_communion',
    formName: 'First Communion Request',
    displayNames: { english: 'First Communion', tagalog: 'Unang Komunyon' },
    descriptions: {
      english: 'First Communion is the first reception of the Holy Eucharist. A special celebration for students preparing for their first reception of the Body and Blood of Christ.',
      tagalog: 'Ang Unang Komunyon ay ang unang pagtanggap ng Banal na Eukaristiya. Isang espesyal na pagdiriwang para sa mga mag-aaral na naghahanda para sa kanilang unang pagtanggap ng katawan at dugo ni Kristo.',
    },
    fields: [
      '[SECTION] SCHOOL INFORMATION (Impormasyon ng Paaralan)', 'School Name (Pangalan ng Paaralan) *', 'School Address (Tirahan ng Paaralan) *',
      'School Contact Number (Numero ng Telepono) *', 'School Email Address (Email) *', 'Principal Name (Pangalan ng Principal) *',
      '[SECTION] REQUEST DETAILS (Detalye ng Kahilingan)', 'Number of Students (Bilang ng Mag-aaral) *', 'Grade Level (Baitang) *',
      'Preferred Date (Petsa na Nais) *', 'Preferred Time (Oras na Nais) *', 'Alternative Date (Alternatibong Petsa)',
      '[SECTION] CONTACT PERSON (Contact Person)', 'Contact Person Name (Pangalan ng Kontak) *', 'Contact Person Number (Numero ng Kontak) *',
      'Contact Person Email (Email ng Kontak) *', '[SECTION] ADDITIONAL INFORMATION (Karagdagang Impormasyon)', 'Special Requests (Espesyal na Kahilingan)', 'Additional Notes (Karagdagang Paalala)',
    ],
    requirements: [],
    fees: { currency: 'PHP', base: 0 },
    schedules: { dateFieldKeys: ['Preferred Date (Petsa na Nais) *'], timeFieldKeys: ['Preferred Time (Oras na Nais) *'] },
    active: true,
  },
};

exports.seedBookingForms = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').where('uid', '==', uid).limit(1).get();
    if (userDoc.empty || userDoc.docs[0].data().role !== 'admin') {
      throw new HttpsError('permission-denied', 'Only admins can seed booking forms');
    }

    const batch = db.batch();
    Object.entries(DEFAULT_BOOKING_FORMS).forEach(([formKey, form]) => {
      batch.set(
        db.collection('booking_forms').doc(formKey),
        {
          ...form,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
    await batch.commit();

    return {
      success: true,
      collection: 'booking_forms',
      count: Object.keys(DEFAULT_BOOKING_FORMS).length,
    };
  }
);

exports.submitNonMonetaryDonation = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    try {
      const data = request.data || {};

      // Normalize fields to accept both canonical and alias fields
      const normalizedData = normalizeFields(data, 'donation');
      
      // Validate required canonical fields
      const validationErrors = validateCanonicalFields(normalizedData, 'donation');
      if (validationErrors.length > 0) {
        throw new HttpsError('invalid-argument', `Validation failed: ${validationErrors.join(', ')}`);
      }

      const donationType = requireNonEmptyString(normalizedData.donationType, 'donationType');
      const isAnonymous = Boolean(normalizedData.isAnonymous);

      const amountNumber = Number(normalizedData.amount || 0);
      const paymentMethod = (normalizedData.paymentMethod || 'cash').toString().trim() || 'cash';

      const uid = request.auth?.uid || '';
      const isAuthenticated = !!uid;
      
      // Name is required for guest non-anonymous donations
      let name;
      if (isAnonymous) {
        name = 'Anonymous';
      } else if (!isAuthenticated) {
        // Guest non-anonymous: name is required
        name = (normalizedData.name || '').toString().trim();
        if (!name) {
          throw new HttpsError('invalid-argument', 'Name is required for non-anonymous donations.');
        }
      } else {
        // Logged-in non-anonymous: use provided name or default
        name = (normalizedData.name || request.auth?.token?.name || 'Anonymous').toString().trim() || 'Anonymous';
      }
      
      const email = (normalizedData.email || '').toString().trim();
      // Email is optional for anonymous, required for non-anonymous
      if (!isAnonymous && !isValidEmail(email)) {
        throw new HttpsError('invalid-argument', 'A valid email address is required for non-anonymous donations.');
      }

      const userName = request.auth?.token?.name || name;
      const userEmail = request.auth?.token?.email || email;

      const db = admin.firestore();
      const structuredId = await generateStructuredId(db, 'donation');
      const donationRef = db.collection('donations').doc(structuredId);

      await donationRef.set({
        structuredId: structuredId,
        userId: uid,
        userName,
        userEmail,
        donationType,
        isAnonymous,
        amount: Number.isFinite(amountNumber) ? amountNumber : 0,
        currency: 'PHP',
        paymentMethod,
        name,
        email,
        phone: (normalizedData.phone || '').toString().trim(),
        items: (normalizedData.items || '').toString().trim(),
        description: (normalizedData.description || '').toString().trim(),
        message: (normalizedData.message || '').toString().trim(),
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
      });

      return {
        donationId: donationRef.id,
        status: 'ok',
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('submitNonMonetaryDonation unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', err?.message ? String(err.message) : 'Unknown internal error');
    }
  }
);

exports.notifyNonMonetaryDonation = onDocumentCreated(
  {
    region: 'asia-southeast1',
    document: 'donations/{donationId}',
    secrets: [SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const donationId = event.params.donationId;

    const donationType = (data.donationType || '').toString().trim();
    const paymentMethod = (data.paymentMethod || '').toString().trim();
    const isAnonymous = Boolean(data.isAnonymous);
    const donorEmail = (data.email || '').toString().trim();
    const donorName = (data.name || 'Donor').toString();

    const isMonetary = donationType.toLowerCase() === 'monetary' || paymentMethod === 'xendit';
    if (isMonetary) return;
    
    // For anonymous donations, only send if email is provided (optional receipt)
    // For non-anonymous, always try to send to the user's email
    if (!isValidEmail(donorEmail)) return;

    const ref = snap.ref;
    const latestBeforeSend = await ref.get();
    const latestBeforeSendData = latestBeforeSend.data() || {};
    const alreadySent = Boolean(latestBeforeSendData?.notifications?.contactEmailSentAt);
    if (alreadySent) return;

    try {
      await sendDonationContactEmails({
        donationId,
        donorName,
        donorEmail,
        donationType: donationType || 'in_kind',
        amount: Number(data.amount || 0),
        phone: (data.phone || '').toString().trim(),
        items: (data.items || '').toString().trim(),
        description: (data.description || '').toString().trim(),
        message: (data.message || '').toString().trim(),
      });

      await admin.firestore().runTransaction(async (tx) => {
        const latest = await tx.get(ref);
        const latestData = latest.data() || {};
        const sentAlready = Boolean(latestData?.notifications?.contactEmailSentAt);
        if (sentAlready) return;
        tx.set(
          ref,
          {
            notifications: {
              contactEmailSentAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          { merge: true }
        );
      });

      console.log('notifyNonMonetaryDonation contact emails sent', { donationId });
    } catch (emailErr) {
      console.error('notifyNonMonetaryDonation failed', {
        donationId,
        donorEmail,
        message: emailErr?.message,
        stack: emailErr?.stack,
      });
    }
  }
);

exports.xenditWebhook = onRequest(
  {
    region: 'asia-southeast1',
    secrets: [XENDIT_WEBHOOK_TOKEN, SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (req, res) => {
    const webhookId = `webhook-${Date.now()}`;
    console.log(`[${webhookId}] xenditWebhook started`, {
      method: req.method,
      timestamp: new Date().toISOString(),
    });

    try {
      if (req.method !== 'POST') {
        console.warn(`[${webhookId}] Invalid method: ${req.method}`);
        res.status(405).send('Method Not Allowed');
        return;
      }

      const expectedToken = (XENDIT_WEBHOOK_TOKEN.value() || '').toString().trim();
      if (expectedToken) {
        const receivedToken = (req.get('x-callback-token') || '').toString().trim();
        if (!receivedToken || receivedToken !== expectedToken) {
          console.warn(`[${webhookId}] Invalid callback token`);
          res.status(401).send('Unauthorized');
          return;
        }
      }

      const event = req.body || {};
      const invoiceId = String(event.id || '').trim();
      const externalId = String(event.external_id || '').trim();
      const status = String(event.status || '').trim().toUpperCase();

      console.log(`[${webhookId}] xenditWebhook received`, {
        invoiceId,
        externalId,
        status,
        eventKeys: Object.keys(event),
      });

      if (!externalId) {
        console.warn(`[${webhookId}] Missing external_id in event`);
        res.status(200).send('Missing external_id');
        return;
      }

      const db = admin.firestore();
      
      // Try to find the document by externalId first
      console.log(`[${webhookId}] Looking up documents for externalId: ${externalId}`);
      const donationRef = db.collection('donations').doc(externalId);
      const donationSnap = await donationRef.get();
      
      const massOfferingRef = db.collection('mass_offerings').doc(externalId);
      const massOfferingSnap = await (donationSnap.exists ? Promise.resolve(null) : massOfferingRef.get());

      const bookingRef = db.collection('bookings').doc(externalId);
      const bookingSnap = donationSnap.exists || (massOfferingSnap && massOfferingSnap.exists)
        ? null
        : await bookingRef.get();

      let resolvedDonationSnap = donationSnap.exists ? donationSnap : (massOfferingSnap && massOfferingSnap.exists ? massOfferingSnap : null);
      let resolvedBookingSnap = bookingSnap;

      console.log(`[${webhookId}] Document lookup results`, {
        donationExists: donationSnap.exists,
        massOfferingExists: massOfferingSnap && massOfferingSnap.exists,
        bookingExists: bookingSnap && bookingSnap.exists,
      });

      // If not found by externalId, search by invoiceId
      if ((!resolvedDonationSnap || !resolvedDonationSnap.exists) && !(resolvedBookingSnap && resolvedBookingSnap.exists) && invoiceId) {
        console.log(`[${webhookId}] Document not found by externalId, searching by invoiceId: ${invoiceId}`);
        
        const donationMatch = await db
          .collection('donations')
          .where('xendit.invoiceId', '==', invoiceId)
          .limit(1)
          .get();
        if (!donationMatch.empty) {
          resolvedDonationSnap = donationMatch.docs[0];
          console.log(`[${webhookId}] Found donation by invoiceId`);
        } else {
          const massOfferingMatch = await db
            .collection('mass_offerings')
            .where('xendit.invoiceId', '==', invoiceId)
            .limit(1)
            .get();
          if (!massOfferingMatch.empty) {
            resolvedDonationSnap = massOfferingMatch.docs[0];
            console.log(`[${webhookId}] Found mass offering by invoiceId`);
          } else {
            const bookingMatch = await db
              .collection('bookings')
              .where('xendit.invoiceId', '==', invoiceId)
              .limit(1)
              .get();
            if (!bookingMatch.empty) {
              resolvedBookingSnap = bookingMatch.docs[0];
              console.log(`[${webhookId}] Found booking by invoiceId`);
            }
          }
        }
      }

      if ((!resolvedDonationSnap || !resolvedDonationSnap.exists) && !(resolvedBookingSnap && resolvedBookingSnap.exists)) {
        console.warn(`[${webhookId}] No document found for externalId: ${externalId} or invoiceId: ${invoiceId}`);
        res.status(200).send('Reference not found');
        return;
      }

      const targetType = resolvedDonationSnap && resolvedDonationSnap.exists ? 'donation' : 'booking';
      const targetRef = resolvedDonationSnap && resolvedDonationSnap.exists ? resolvedDonationSnap.ref : resolvedBookingSnap.ref;
      const targetId = targetRef.id;

      console.log(`[${webhookId}] Processing ${status} status update for ${targetType}: ${targetId}`);

      const updateData = {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        xendit: {
          invoiceId: invoiceId || null,
          status: status.toLowerCase(),
        },
      };

      if (status === 'PAID' || status === 'SETTLED') {
        console.log(`[${webhookId}] Setting ${targetType} status to PAID`);
        updateData.status = 'paid';
        updateData.xendit.paidAt = admin.firestore.FieldValue.serverTimestamp();
        if (status === 'SETTLED') {
          updateData.xendit.settledAt = admin.firestore.FieldValue.serverTimestamp();
        }
      } else if (status === 'EXPIRED' || status === 'FAILED') {
        console.log(`[${webhookId}] Setting ${targetType} status to FAILED`);
        updateData.status = 'failed';
      }

      // Perform the update
      console.log(`[${webhookId}] Executing update on ${targetType} ${targetId}`, updateData);
      await targetRef.set(updateData, { merge: true });

      // Verify the update was successful
      const updatedSnap = await targetRef.get();
      const updatedData = updatedSnap.data();
      console.log(`[${webhookId}] Update successful! Verified document state:`, {
        id: updatedSnap.id,
        status: updatedData.status,
        xenditStatus: updatedData.xendit?.status,
        paidAt: updatedData.xendit?.paidAt ? 'present' : 'missing',
      });

      res.status(200).send('ok');
    } catch (e) {
      console.error(`[${webhookId}] xenditWebhook unhandled error`, {
        message: e?.message,
        code: e?.code,
        stack: e?.stack,
        timestamp: new Date().toISOString(),
      });
      res.status(500).send('error');
    }
  }
);

// Password Reset OTP Functions
exports.requestPasswordResetOtp = onCall(
  {
    region: 'asia-southeast1',
    secrets: [SMTP_USER, SMTP_APP_PASSWORD, SMTP_FROM_NAME],
  },
  async (request) => {
    const { email } = request.data;
    
    if (!email || !isValidEmail(email)) {
      throw new HttpsError('invalid-argument', 'Valid email is required.');
    }

    const normalizedEmail = normalizeEmail(email);
    const db = admin.firestore();

    try {
      // Check if user exists
      const userRecord = await admin.auth().getUserByEmail(normalizedEmail).catch(() => null);
      
      if (!userRecord) {
        throw new HttpsError('not-found', 'No account found with this email address.');
      }

      // Generate OTP and salt
      const otp = generateOtpCode();
      const salt = crypto.randomBytes(16).toString('hex');
      const hashedOtp = hashOtp({ email: normalizedEmail, otp, salt });

      // Store OTP in Firestore (expires in 10 minutes)
      await db.collection('passwordResetOtps').doc(normalizedEmail).set({
        email: normalizedEmail,
        hashedOtp,
        salt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000)),
        attempts: 0,
      });

      // Send email
      const smtpUser = SMTP_USER.value();
      const smtpPass = SMTP_APP_PASSWORD.value();
      const fromName = SMTP_FROM_NAME.value() || 'Sto. Rosario Parish Church';

      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: { user: smtpUser, pass: smtpPass },
      });

      const mailOptions = {
        from: `"${fromName}" <${smtpUser}>`,
        to: normalizedEmail,
        subject: 'Password Reset OTP - Sto. Rosario Parish Church',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
            <h2 style="color: #1e3a8a; text-align: center;">Password Reset Request</h2>
            <p>Hello,</p>
            <p>We received a request to reset your password for your Sto. Rosario Parish Church account.</p>
            <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
              <p style="margin: 0; font-size: 14px; color: #6b7280;">Your One-Time Password (OTP)</p>
              <p style="margin: 10px 0; font-size: 32px; font-weight: bold; color: #1e3a8a; letter-spacing: 4px;">${otp}</p>
            </div>
            <p style="color: #dc2626; font-size: 14px;">⏰ This OTP will expire in 10 minutes.</p>
            <p style="font-size: 12px; color: #6b7280; margin-top: 30px;">
              If you didn't request this password reset, please ignore this email. Your account is safe.
            </p>
            <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
            <p style="font-size: 12px; color: #9ca3af; text-align: center;">
              Sto. Rosario Parish Church Management System
            </p>
          </div>
        `,
      };

      await transporter.sendMail(mailOptions);
      console.log('Password reset OTP sent to:', normalizedEmail);

      return { success: true, message: 'OTP sent successfully' };

    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('requestPasswordResetOtp unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', 'Failed to send OTP. Please try again later.');
    }
  }
);

exports.verifyPasswordResetOtpAndResetPassword = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    const { email, otp, newPassword } = request.data;
    
    if (!email || !isValidEmail(email)) {
      throw new HttpsError('invalid-argument', 'Valid email is required.');
    }
    if (!otp || otp.length !== 6) {
      throw new HttpsError('invalid-argument', 'Valid 6-digit OTP is required.');
    }
    if (!newPassword || newPassword.length < 6) {
      throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
    }

    const normalizedEmail = normalizeEmail(email);
    const db = admin.firestore();

    try {
      // Get stored OTP
      const otpDoc = await db.collection('passwordResetOtps').doc(normalizedEmail).get();
      
      if (!otpDoc.exists) {
        throw new HttpsError('invalid-argument', 'OTP not found or expired. Please request a new OTP.');
      }

      const otpData = otpDoc.data();
      
      // Check if OTP is expired
      if (otpData.expiresAt.toDate() < new Date()) {
        await otpDoc.ref.delete();
        throw new HttpsError('deadline-exceeded', 'OTP has expired. Please request a new OTP.');
      }

      // Verify OTP hash
      const hashedInputOtp = hashOtp({ email: normalizedEmail, otp: String(otp), salt: otpData.salt });
      if (hashedInputOtp !== otpData.hashedOtp) {
        // Increment attempts
        await otpDoc.ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
        
        if (otpData.attempts >= 2) { // 3rd attempt (0, 1, 2)
          await otpDoc.ref.delete();
          throw new HttpsError('permission-denied', 'Too many failed attempts. Please request a new OTP.');
        }
        
        throw new HttpsError('invalid-argument', `Invalid OTP. ${3 - (otpData.attempts + 1)} attempts remaining.`);
      }

      // Get user and update password
      const userRecord = await admin.auth().getUserByEmail(normalizedEmail);
      await admin.auth().updateUser(userRecord.uid, {
        password: newPassword,
      });

      // Delete OTP document
      await otpDoc.ref.delete();
      
      console.log('Password reset successful for:', normalizedEmail);
      return { success: true, message: 'Password reset successful' };

    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('verifyPasswordResetOtpAndResetPassword unhandled error', {
        message: err?.message,
        stack: err?.stack,
      });
      throw new HttpsError('internal', 'Failed to reset password. Please try again later.');
    }
  }
);

// TEST HELPER: Manually update booking payment status (for testing webhook behavior)
// This is useful when testing in staging environment
exports.testUpdateBookingPaymentStatus = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    // Only allow admin users or during testing
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    const { bookingId, status } = request.data;

    if (!bookingId) {
      throw new HttpsError('invalid-argument', 'bookingId is required');
    }

    if (!status || !['paid', 'settled', 'failed', 'pending'].includes(status.toLowerCase())) {
      throw new HttpsError('invalid-argument', 'Valid status required: paid, settled, failed, pending');
    }

    const db = admin.firestore();
    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await bookingRef.get();

    if (!bookingSnap.exists) {
      throw new HttpsError('not-found', `Booking not found: ${bookingId}`);
    }

    const bookingData = bookingSnap.data();

    // Allow booking owner to update their own booking status
    if (bookingData.userId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'You can only update your own bookings');
    }

    const normalizedStatus = status.toLowerCase();
    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      xendit: {
        invoiceId: bookingData?.xendit?.invoiceId || null,
        status: normalizedStatus === 'paid' ? 'PAID' : normalizedStatus === 'settled' ? 'SETTLED' : normalizedStatus.toUpperCase(),
      },
    };

    if (normalizedStatus === 'paid' || normalizedStatus === 'settled') {
      updateData.status = 'paid';
      updateData.xendit.paidAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (normalizedStatus === 'failed') {
      updateData.status = 'failed';
    }

    await bookingRef.set(updateData, { merge: true });

    console.log('testUpdateBookingPaymentStatus: Updated booking', {
      bookingId,
      userId: request.auth.uid,
      newStatus: updateData.status,
      timestamp: new Date().toISOString(),
    });

    return {
      success: true,
      message: `Booking ${bookingId} updated to status: ${updateData.status}`,
      booking: (await bookingRef.get()).data(),
    };
  }
);

// ============================================================================
// SCHEDULING ENGINE FUNCTIONS
// ============================================================================

/**
 * Cloud Function: getAvailableSlots
 * Returns available time slots for a given sacrament on a specific date
 * Prevents double bookings and respects Mass schedule
 */
exports.getAvailableSlots = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    try {
      const data = request.data || {};
      const sacramentType = String(data.sacramentType || '').toLowerCase().trim();
      const date = String(data.date || '').trim();

      if (!sacramentType) {
        throw new HttpsError('invalid-argument', 'sacramentType is required');
      }
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
        throw new HttpsError('invalid-argument', 'date must be in YYYY-MM-DD format');
      }

      const db = admin.firestore();
      const parsedDate = new Date(date + 'T00:00:00Z');

      // Mass Intention: multiple bookings allowed at same time
      if (sacramentType === 'massintention' || sacramentType === 'mass_intention') {
        const massSchedules = await db
          .collection('massSchedules')
          .where('dayOfWeek', '==', getDayName(parsedDate))
          .get();

        const slots = massSchedules.docs.map(doc => {
          const data = doc.data();
          return {
            date,
            time: data.startTime,
            label: formatTimeLabel(data.startTime),
            available: true,
          };
        });

        return { slots };
      }

      // For exclusive sacraments, check for conflicts
      const existingBookings = await db
        .collection('bookings')
        .where('sacramentType', '==', sacramentType)
        .where('status', 'in', ['approved', 'accepted', 'confirmed', 'pending'])
        .get();

      const bookedSlots = new Set();
      existingBookings.docs.forEach(doc => {
        const booking = doc.data();
        if (booking.date === date && booking.time) {
          bookedSlots.add(booking.time);
        }
      });

      // Generate available slots for the day
      const slots = [];
      const slotDuration = 30; // minutes

      if (sacramentType === 'wedding') {
        // Weddings: only 10 AM and 2 PM slots
        const weddingCount = existingBookings.docs.filter(d => {
          const b = d.data();
          return b.date === date && b.status !== 'cancelled';
        }).length;

        if (weddingCount < 2) {
          const slots10am = {
            date,
            time: '10:00',
            label: '10:00 AM',
            available: !bookedSlots.has('10:00'),
          };
          const slots2pm = {
            date,
            time: '14:00',
            label: '2:00 PM',
            available: !bookedSlots.has('14:00'),
          };

          if (!bookedSlots.has('10:00')) slots.push(slots10am);
          if (weddingCount < 1 && !bookedSlots.has('14:00')) slots.push(slots2pm);
        }
      } else {
        // Other sacraments: 30-minute slots from 7 AM to 5 PM
        for (let hour = 7; hour < 17; hour++) {
          for (let minute of [0, 30]) {
            const timeStr = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
            const available = !bookedSlots.has(timeStr);

            slots.push({
              date,
              time: timeStr,
              label: formatTimeLabel(timeStr),
              available,
            });
          }
        }
      }

      return { slots };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('getAvailableSlots error:', err?.message);
      throw new HttpsError('internal', err?.message || 'Unknown error');
    }
  }
);

/**
 * Cloud Function: checkSchedulingConflict
 * Checks if a proposed booking conflicts with existing bookings or Mass schedule
 */
exports.checkSchedulingConflict = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    try {
      const data = request.data || {};
      const sacramentType = String(data.sacramentType || '').trim();
      const date = String(data.date || '').trim();
      const time = String(data.time || '').trim();
      const bookingId = String(data.bookingId || '').trim();

      if (!sacramentType || !date || !time) {
        throw new HttpsError('invalid-argument', 'sacramentType, date, and time are required');
      }

      const db = admin.firestore();
      const canonicalType = canonicalSacramentType(sacramentType) || sacramentType.toLowerCase();
      const requestedMinutes = parseTimeToMinutes(time);
      if (requestedMinutes == null) {
        throw new HttpsError('invalid-argument', 'time must be in HH:MM or h:mm AM/PM format.');
      }
      const requestedPeriod = schedulePeriodFromMinutes(requestedMinutes);

      // Mass Intention: no conflicts with other intentions, but schedule must exist.
      if (isMassIntention(canonicalType)) {
        const isValidMassSchedule = await validateMassIntentionSchedule(db, date, time);
        if (!isValidMassSchedule) {
          return {
            hasConflict: true,
            reason: 'The selected date and time does not match any official Mass schedule.',
            conflictingBookings: [],
          };
        }

        return {
          hasConflict: false,
          reason: null,
          conflictingBookings: [],
        };
      }

      // Check for existing bookings at the same time
      const conflictingBookings = [];
      const existingBookings = await db
        .collection('bookings')
        .where('date', '==', date)
        .where('status', 'in', ACTIVE_BOOKING_STATUSES)
        .get();
      const existingOldRequests = await db
        .collection('sacrament_requests')
        .where('status', 'in', ACTIVE_BOOKING_STATUSES)
        .get();

      for (const doc of [...existingBookings.docs, ...existingOldRequests.docs]) {
        if (bookingId && doc.id === bookingId) continue; // Skip self

        const booking = doc.data();
        const {
          canonicalType: bookingCanonicalType,
          date: bookingDate,
          time: bookingTime,
        } = bookingScheduleValues(booking, canonicalType);
        if (!isRestrictedService(bookingCanonicalType)) continue;
        if (bookingDate !== date) continue;

        const bookingMinutes = parseTimeToMinutes(String(bookingTime || ''));
        if (bookingMinutes == null) continue;

        if (Math.abs(bookingMinutes - requestedMinutes) < 60) {
          conflictingBookings.push(doc.id);
          continue;
        }

        if (
          bookingCanonicalType === canonicalType &&
          schedulePeriodFromMinutes(bookingMinutes) === requestedPeriod
        ) {
          conflictingBookings.push(doc.id);
        }
      }

      if (conflictingBookings.length > 0) {
        return {
          hasConflict: true,
          reason: `The selected date and time conflicts with another approved booking. Only 1 ${canonicalType} booking is allowed in the ${requestedPeriod} schedule and bookings must be at least 1 hour apart.`,
          conflictingBookings,
        };
      }

      return {
        hasConflict: false,
        reason: null,
        conflictingBookings: [],
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('checkSchedulingConflict error:', err?.message);
      throw new HttpsError('internal', err?.message || 'Unknown error');
    }
  }
);

/**
 * Cloud Function: createMassSchedule
 * Admin function to create/update official Mass schedule
 */
exports.createMassSchedule = onCall(
  {
    region: 'asia-southeast1',
  },
  async (request) => {
    try {
      const data = request.data || {};

      // Check if user is admin
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }

      const db = admin.firestore();
      const userDoc = await db.collection('users').where('uid', '==', uid).limit(1).get();
      if (userDoc.empty || userDoc.docs[0].data().role !== 'admin') {
        throw new HttpsError('permission-denied', 'Only admins can manage Mass schedules');
      }

      const dayOfWeek = String(data.dayOfWeek || '').trim();
      const startTime = String(data.startTime || '').trim();
      const endTime = String(data.endTime || '').trim();

      if (!dayOfWeek || !startTime) {
        throw new HttpsError('invalid-argument', 'dayOfWeek and startTime are required');
      }

      const massScheduleId = await generateStructuredId(db, 'mass_schedule');

      await db.collection('massSchedules').doc(massScheduleId).set({
        structuredId: massScheduleId,
        dayOfWeek,
        startTime,
        endTime: endTime || startTime,
        active: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { scheduleId: massScheduleId };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('createMassSchedule error:', err?.message);
      throw new HttpsError('internal', err?.message || 'Unknown error');
    }
  }
);

// Helper functions for scheduling

function getDayName(date) {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return days[date.getUTCDay()];
}

function formatTimeLabel(timeStr) {
  if (!timeStr) return '';
  const [hour, minute] = timeStr.split(':');
  const h = parseInt(hour);
  const ampm = h >= 12 ? 'PM' : 'AM';
  const displayHour = h > 12 ? h - 12 : (h === 0 ? 12 : h);
  return `${displayHour}:${minute} ${ampm}`;
}

function timeConflict(time1, time2, durationMinutes) {
  const [h1, m1] = time1.split(':').map(Number);
  const [h2, m2] = time2.split(':').map(Number);

  const minutes1 = h1 * 60 + m1;
  const minutes2 = h2 * 60 + m2;
  const end1 = minutes1 + durationMinutes;

  return (minutes2 >= minutes1 && minutes2 < end1) ||
         (minutes1 >= minutes2 && minutes1 < (minutes2 + durationMinutes));
}
