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
  const ownerId = data.owner_id; // Ab URL se nahi, data ke andar se ID nikal rahe hain
  const studentName = data.student_name || "Ek Student";

  await sendNotificationToUser(ownerId, "Naya Student Aaya Hai! 🎉", `${studentName} ne mess join karne ki request bheji hai.`);
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
    await sendNotificationToUser(ownerId, "Payment Verification 💸", `${studentName} bol raha hai usne ₹${amt} pay kar diye hain. Check karke Verify kar!`);
  }

  // Live Chowkidar (Scan Notification)
  if (data.isPending === false && (!data.amount || data.amount === 0 || data.amount === "0")) {
      const studentName = data.name || "Student";
      const mealType = data.type || "Khana";

      try {
        const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (ownerDoc.exists) {
            const wantsNotification = ownerDoc.data().notify_on_scan !== false;
            if (wantsNotification) {
                await sendNotificationToUser(ownerId, "Live Scan 🔔", `${studentName} ne abhi ${mealType} scan kiya hai.`);
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

  await sendNotificationToUser(ownerId, "Nayi Complaint Aayi Hai 🚨", "Kisi student ne issue report kiya hai. Dashboard mein check kar.");
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
    await sendNotificationToUser(studentUid, "Payment Verified! ✅", `Owner ne tumhara ₹${amt} ka payment confirm kar diya hai. Dues clear!`);
  }
});

// 5. 🚀 NAYA RASTA: Owner Student ki Join Request Accept ya Reject Kar Le
exports.notifyStudentOnAcceptOrReject = onDocumentUpdated("join_requests/{reqId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const studentId = after.student_id; // Chitthi se student ki ID uthayi

  // Agar pending se ACCEPTED hua
  if (before.status === 'pending' && after.status === 'accepted') {
    await sendNotificationToUser(studentId, "Pass Activated! 🎉", "Owner ne tumhari request approve kar di hai. Aaja khana kha le!");
  }
  // Agar pending se REJECTED hua (Ye naya add kiya hai tere liye!)
  else if (before.status === 'pending' && after.status === 'rejected') {
    await sendNotificationToUser(studentId, "Request Declined ❌", "Owner ne tumhari mess join request cancel kar di hai.");
  }
});

// 6. Owner Menu Update Kare / Polling Start Kare / Mess Close Kare (BROADCAST)
exports.notifyStudentsOnMessUpdates = onDocumentUpdated("users/{ownerId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const ownerId = event.params.ownerId;
  const messName = after.mess_name || "Mess";

  let title = "";
  let body = "";

  if (before.today_menu !== after.today_menu) {
    title = `Menu Updated! 😋 (${messName})`;
    body = `Aaj ban raha hai: ${after.today_menu}`;
  } else if (before.is_voting_active === false && after.is_voting_active === true) {
    title = `Sunday Special Voting Live! 🗳️`;
    body = `${messName} mein voting shuru ho gayi hai. Apni pasand ka khana vote karo!`;
  } else if (before.is_open === true && after.is_open === false) {
    title = `Mess Closed 🛑`;
    body = `${messName} ne abhi status 'Closed' kar diya hai. Update check karo.`;
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
            return { success: true, message: "Sabke paise chukta hain, koi defaulter nahi! 🎉" };
        }

        await admin.messaging().sendEachForMulticast({
            tokens: tokensToPing,
            notification: {
                title: `⚠️ Pending Dues Reminder`,
                body: `${ownerName} owner ne payment reminder bheja hai. Kripya apne pending dues clear karein. 💸`
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