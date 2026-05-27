const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Generate OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Configure email transporter (use your email service)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().email.user,
    pass: functions.config().email.pass,
  },
});

// Request Password Reset OTP
exports.requestPasswordResetOtp = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    const { email } = data;
    
    if (!email) {
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }

    try {
      // Check if user exists
      const userRecord = await admin.auth().getUserByEmail(email).catch(() => null);
      
      if (!userRecord) {
        throw new functions.https.HttpsError('not-found', 'User not found');
      }

      // Generate OTP
      const otp = generateOTP();
      
      // Store OTP in Firestore (expires in 10 minutes)
      await admin.firestore().collection('passwordResetOtps').doc(email).set({
        otp: otp,
        email: email,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000)),
        attempts: 0,
      });

      // Send email
      const mailOptions = {
        from: functions.config().email.user,
        to: email,
        subject: 'Password Reset OTP - Sto. Rosario Parish Church',
        html: `
          <h2>Password Reset Request</h2>
          <p>Your OTP for password reset is: <strong>${otp}</strong></p>
          <p>This OTP will expire in 10 minutes.</p>
          <p>If you didn't request this, please ignore this email.</p>
        `,
      };

      await transporter.sendMail(mailOptions);
      
      return { success: true, message: 'OTP sent successfully' };
      
    } catch (error) {
      console.error('Error sending OTP:', error);
      throw new functions.https.HttpsError('internal', 'Failed to send OTP');
    }
  });

// Verify OTP and Reset Password
exports.verifyPasswordResetOtpAndResetPassword = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    const { email, otp, newPassword } = data;
    
    if (!email || !otp || !newPassword) {
      throw new functions.https.HttpsError('invalid-argument', 'Email, OTP, and new password are required');
    }

    try {
      // Get stored OTP
      const otpDoc = await admin.firestore().collection('passwordResetOtps').doc(email).get();
      
      if (!otpDoc.exists) {
        throw new functions.https.HttpsError('invalid-argument', 'OTP not found or expired');
      }

      const otpData = otpDoc.data();
      
      // Check if OTP is expired
      if (otpData.expiresAt.toDate() < new Date()) {
        await otpDoc.ref.delete();
        throw new functions.https.HttpsError('deadline-exceeded', 'OTP has expired');
      }

      // Verify OTP
      if (otpData.otp !== otp) {
        // Increment attempts
        await otpDoc.ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
        
        if (otpData.attempts >= 3) {
          await otpDoc.ref.delete();
          throw new functions.https.HttpsError('permission-denied', 'Too many failed attempts. Please request a new OTP.');
        }
        
        throw new functions.https.HttpsError('invalid-argument', 'Invalid OTP');
      }

      // Get user and update password
      const userRecord = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(userRecord.uid, {
        password: newPassword,
      });

      // Delete OTP document
      await otpDoc.ref.delete();
      
      return { success: true, message: 'Password reset successful' };
      
    } catch (error) {
      console.error('Error verifying OTP:', error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError('internal', 'Failed to reset password');
    }
  });
