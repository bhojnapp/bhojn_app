const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// ============================================================================
// 👑 TO OWNER NOTIFICATIONS (Student se Owner tak)
// ============================================================================

// 1. 🚀 NAYA RASTA: Naya Student Join Request Bheje (Global Collection se)
exports.notifyOwnerOnNewRequest = onDocumentCreated("join_requests/{reqId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();
  const ownerId = data.owner_id;
  const studentName = data.student_name || "A Student";

  await sendNotificationToUser(ownerId, "New Join Request 🎉", `${studentName} has requested to join your mess. Please review.`);
});

// 2. Student Due Payment Verify karne ki Request Bheje & Live Chowkidar Scan
exports.notifyOwnerOnPaymentClaim = onDocumentCreated("users/{ownerId}/recent_transactions/{txnId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const ownerId = event.params.ownerId;

  // Agar ye payment claim hai
  if (data.isPending === true && data.type.includes('Payment')) {
    const studentName = data.name || "Student";
    const amt = data.amount || 0;
    await sendNotificationToUser(ownerId, "Payment Verification Required 💸", `${studentName} has reported a payment of ₹${amt}. Please verify this transaction.`);
  }

  // 🚀 UPDATE: Live Chowkidar (Scan Notification) with Dynamic Title
  if (data.isPending === false && (!data.amount || data.amount === 0 || data.amount === "0")) {
      const studentName = data.name || "Student";
      const mealType = data.type || "Meal";

      try {
        const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (ownerDoc.exists) {
            const wantsNotification = ownerDoc.data().notify_on_scan !== false;
            if (wantsNotification) {
                // Yahan apan ne Title mein Student ka naam aur Session daal diya!
                const title = `${studentName} - ${mealType} 🍽️`;
                const body = `Pass scanned successfully.`;
                await sendNotificationToUser(ownerId, title, body);
            }
        }
      } catch(e) {
          console.error("Error in Live Chowkidar trigger: ", e);
      }
  }
});

// 3. Student Koi Complaint/Report Bheje
exports.notifyOwnerOnComplaint = onDocumentCreated("users/{ownerId}/complaints/{compId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const ownerId = event.params.ownerId;

  await sendNotificationToUser(ownerId, "New Feedback/Report 🚨", "A student has submitted a new report. Please check your dashboard for details.");
});


// ============================================================================
// 👨‍🎓 TO STUDENT NOTIFICATIONS (Owner se Student tak)
// ============================================================================

// 4. Owner Payment Verify (Confirm) Kar De
exports.notifyStudentOnPaymentVerify = onDocumentUpdated("users/{ownerId}/recent_transactions/{txnId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // Agar isPending true se false hua hai
  if (before.isPending === true && after.isPending === false) {
    const studentUid = after.uid;
    const amt = after.amount || 0;
    await sendNotificationToUser(studentUid, "Payment Verified! ✅", `Your payment of ₹${amt} has been successfully verified by the mess owner.`);
  }
});

// 5. 🚀 NAYA RASTA: Owner Student ki Join Request Accept ya Reject Kar Le
exports.notifyStudentOnAcceptOrReject = onDocumentUpdated("join_requests/{reqId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const studentId = after.student_id;

  // Agar pending se ACCEPTED hua
  if (before.status === 'pending' && after.status === 'accepted') {
    await sendNotificationToUser(studentId, "Mess Pass Activated! 🎉", "Your request to join the mess has been approved. You can now scan for meals.");
  }
  // Agar pending se REJECTED hua
  else if (before.status === 'pending' && after.status === 'rejected') {
    await sendNotificationToUser(studentId, "Request Declined ❌", "Your request to join the mess was declined by the owner.");
  }
});

// 6. Owner Menu Update Kare / Polling Start Kare / Mess Close Kare (BROADCAST)
exports.notifyStudentsOnMessUpdates = onDocumentUpdated("users/{ownerId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const ownerId = event.params.ownerId;
  const messName = after.mess_name || "Your Mess";

  let title = "";
  let body = "";

  if (before.today_menu !== after.today_menu) {
    title = `Today's Menu Updated! 😋 (${messName})`;
    body = `Today's special: ${after.today_menu}`;
  } else if (before.is_voting_active === false && after.is_voting_active === true) {
    title = `Special Menu Voting is Live! 🗳️`;
    body = `Voting is now open for ${messName}. Cast your vote in the app now!`;
  } else if (before.is_open === true && after.is_open === false) {
    title = `Mess Status: Closed 🛑`;
    body = `${messName} is currently closed. Please check the app for further updates.`;
  }

  if (title !== "") {
    await broadcastToActiveStudents(ownerId, title, body);
  }
});


// ============================================================================
// 🚀 FIXED FEATURE: The "Vasooli" Button (Send Due Reminders) v2
// ============================================================================
exports.remindDefaulters = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be logged in to send reminders.");
    }

    const ownerId = request.auth.uid;
    const ownerName = request.data?.messName || "Your Mess";

    try {
        const studentsSnap = await admin.firestore().collection("users")
            .where("role", "==", "student")
            .where("active_messes", "array-contains", ownerId)
            .get();

        const tokensToPing = [];

        studentsSnap.forEach(doc => {
            const sData = doc.data();
            const fcmToken = sData.fcmToken;
            const messData = sData.mess_data || {};
            const specificMess = messData[ownerId] || {};
            const pendingDues = parseFloat(specificMess.pending_dues || sData.pending_dues || 0);

            if (pendingDues > 0 && fcmToken) {
                tokensToPing.push(fcmToken);
            }
        });

        if (tokensToPing.length === 0) {
            return { success: true, message: "All dues are clear, no defaulters found! 🎉" };
        }

        await admin.messaging().sendEachForMulticast({
            tokens: tokensToPing,
            notification: {
                title: `⚠️ Payment Reminder`,
                body: `This is a gentle reminder from ${ownerName} to clear your pending dues. 💸`
            },
            android: {
                priority: "high",
                notification: { channelId: "bhojn_urgent_channel", sound: "default" }
            },
            apns: {
                payload: { aps: { sound: "default", contentAvailable: true } }
            }
        });

        return { success: true, message: `Reminders successfully sent to ${tokensToPing.length} students. 🚀` };

    } catch (error) {
        console.error("🚨 Error in remindDefaulters function:", error);
        throw new HttpsError("internal", "Server error while sending reminders.");
    }
});


// ============================================================================
// 🛠️ HELPER FUNCTIONS
// ============================================================================

async function sendNotificationToUser(uid, title, body) {
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) return;
    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: {
        priority: "high",
        notification: { channelId: "bhojn_urgent_channel", sound: "default" }
      },
      apns: {
        payload: { aps: { sound: "default", contentAvailable: true } }
      }
    });
  } catch (e) {
    console.error(`🚨 Error sending to ${uid}:`, e);
  }
}

async function broadcastToActiveStudents(ownerId, title, body) {
  try {
    const studentsSnap = await admin.firestore().collection("users")
      .where("role", "==", "student")
      .where("active_messes", "array-contains", ownerId)
      .get();

    const tokens = [];
    studentsSnap.forEach(doc => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      notification: { title, body },
      android: {
        priority: "high",
        notification: { channelId: "bhojn_urgent_channel", sound: "default" }
      },
      apns: {
        payload: { aps: { sound: "default", contentAvailable: true } }
      }
    });
  } catch (e) {
    console.error(`🚨 Error broadcasting:`, e);
  }
}