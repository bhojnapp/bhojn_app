const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// ============================================================================
// 👑 TO OWNER NOTIFICATIONS (Student se Owner tak)
// ============================================================================

// 1. Naya Student Join Request Bheje
exports.notifyOwnerOnNewRequest = onDocumentCreated("users/{ownerId}/join_requests/{studentId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const ownerId = event.params.ownerId;
  const studentName = snap.data().student_name || "Ek Student";

  sendNotificationToUser(ownerId, "Naya Student Aaya Hai! 🎉", `${studentName} ne mess join karne ki request bheji hai.`);
});

// 2. Student Due Payment Verify karne ki Request Bheje
exports.notifyOwnerOnPaymentClaim = onDocumentCreated("users/{ownerId}/recent_transactions/{txnId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data();
  const ownerId = event.params.ownerId;

  // Agar ye payment claim hai
  if (data.isPending === true && data.type.includes('Payment')) {
    const studentName = data.name || "Student";
    const amt = data.amount || 0;
    sendNotificationToUser(ownerId, "Payment Verification 💸", `${studentName} bol raha hai usne ₹${amt} pay kar diye hain. Check karke Verify kar!`);
  }

  // 🚀 FEATURE ADDED: Live Chowkidar (Scan Notification)
  // Agar ye khana khane ka scan hai (amount = 0 aur pending nahi hai)
  if (data.isPending === false && (!data.amount || data.amount === 0 || data.amount === "0")) {
      const studentName = data.name || "Student";
      const mealType = data.type || "Khana"; // e.g. Attendance: Dinner

      try {
        // Owner ki profile check karo ki usey notification chahiye ya nahi
        const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (ownerDoc.exists) {
            const wantsNotification = ownerDoc.data().notify_on_scan !== false; // default true agar set nahi hai toh

            if (wantsNotification) {
                // Owner ko ghanti bajao
                sendNotificationToUser(ownerId, "Live Scan 🔔", `${studentName} ne abhi ${mealType} scan kiya hai.`);
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

  sendNotificationToUser(ownerId, "Nayi Complaint Aayi Hai 🚨", "Kisi student ne issue report kiya hai. Dashboard mein check kar.");
});


// ============================================================================
// 👨‍🎓 TO STUDENT NOTIFICATIONS (Owner se Student tak)
// ============================================================================

// 4. Owner Payment Verify (Confirm) Kar De
exports.notifyStudentOnPaymentVerify = onDocumentUpdated("users/{ownerId}/recent_transactions/{txnId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // Agar isPending true se false hua hai (matlab verify ho gaya)
  if (before.isPending === true && after.isPending === false) {
    const studentUid = after.uid;
    const amt = after.amount || 0;
    sendNotificationToUser(studentUid, "Payment Verified! ✅", `Owner ne tumhara ₹${amt} ka payment confirm kar diya hai. Dues clear!`);
  }
});

// 5. Owner Student ki Join Request Accept Kar Le (Welcome to Mess)
exports.notifyStudentOnAccept = onDocumentUpdated("users/{studentId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const studentId = event.params.studentId;

  const beforeMesses = before.active_messes || [];
  const afterMesses = after.active_messes || [];

  // Agar naya mess add hua hai array mein
  if (afterMesses.length > beforeMesses.length) {
    sendNotificationToUser(studentId, "Pass Activated! 🎉", "Owner ne tumhari request approve kar di hai. Aaja khana kha le!");
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

  // Scenario A: Menu Update Hua
  if (before.today_menu !== after.today_menu) {
    title = `Menu Updated! 😋 (${messName})`;
    body = `Aaj ban raha hai: ${after.today_menu}`;
  }
  // Scenario B: Polling Start Hui
  else if (before.is_voting_active === false && after.is_voting_active === true) {
    title = `Sunday Special Voting Live! 🗳️`;
    body = `${messName} mein voting shuru ho gayi hai. Apni pasand ka khana vote karo!`;
  }
  // Scenario C: Achanak Mess Band Kar Diya (Closed)
  else if (before.is_open === true && after.is_open === false) {
    title = `Mess Closed 🛑`;
    body = `${messName} ne abhi status 'Closed' kar diya hai. Update check karo.`;
  }

  // Agar kuch kaam ka update hua hai, toh sabhi active students ko bhej do
  if (title !== "") {
    broadcastToActiveStudents(ownerId, title, body);
  }
});


// ============================================================================
// 🚀 NEW FEATURE: The "Vasooli" Button (Send Due Reminders)
// ============================================================================
exports.remindDefaulters = onCall(async (request) => {
    // Check if user is authenticated
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "You must be logged in to send reminders.");
    }

    const ownerId = request.auth.uid;
    const ownerName = request.data?.messName || "Your Mess";

    try {
        // 1. Un sabhi baccho ko dhundho jo is owner ke mess mein active hain
        const studentsSnap = await admin.firestore().collection("users")
            .where("role", "==", "student")
            .where("active_messes", "array-contains", ownerId)
            .get();

        const tokensToPing = [];

        studentsSnap.forEach(doc => {
            const sData = doc.data();
            const fcmToken = sData.fcmToken;

            // 2. Check karo ki kya is specific mess ke liye inka dues pending hai
            const messData = sData.mess_data || {};
            const specificMess = messData[ownerId] || {};
            const pendingDues = parseFloat(specificMess.pending_dues || sData.pending_dues || 0);

            // Agar pending due > 0 hai aur fcmToken maujood hai, toh list mein daal do
            if (pendingDues > 0 && fcmToken) {
                tokensToPing.push(fcmToken);
            }
        });

        // 3. Agar koi defaulter nahi mila
        if (tokensToPing.length === 0) {
            return { success: true, message: "Sabke paise chukta hain, koi defaulter nahi!" };
        }

        // 4. Sabhi defaulters ko ek saath notification bhejo (Multicast)
        await admin.messaging().sendEachForMulticast({
            tokens: tokensToPing,
            notification: {
                title: "⚠️ Pending Dues Reminder",
                body: `${ownerName} owner ne payment reminder bheja hai. Kripya apne pending dues clear karein.`
            },
            android: {
                priority: "high",
                notification: { channelId: "bhojn_urgent_channel", sound: "default" }
            },
            apns: {
                payload: { aps: { sound: "default", contentAvailable: true } }
            }
        });

        console.log(`📣 Vasooli Reminder sent to ${tokensToPing.length} defaulters by ${ownerId}`);
        return { success: true, message: `Reminders sent to ${tokensToPing.length} students.` };

    } catch (error) {
        console.error("🚨 Error in remindDefaulters function:", error);
        throw new HttpsError("internal", "Server error while sending reminders.");
    }
});


// ============================================================================
// 🛠️ HELPER FUNCTIONS (The VIP Setup 🚀)
// ============================================================================

// Ek akele bande ko notification bhejne ka function
async function sendNotificationToUser(uid, title, body) {
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) return;
    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      // 🚀 ANDROID VIP BYPASS
      android: {
        priority: "high",
        notification: {
          channelId: "bhojn_urgent_channel", // Flutter wale channel se match kiya
          sound: "default"
        }
      },
      // 🍎 iPHONE VIP BYPASS (Future proofing)
      apns: {
        payload: {
          aps: { sound: "default", contentAvailable: true }
        }
      }
    });
    console.log(`✅ VIP Notification sent to ${uid}: ${title}`);
  } catch (e) {
    console.error(`🚨 Error sending to ${uid}:`, e);
  }
}

// Saare active students ko ek saath (Multicast) bhejne ka function
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
      // 🚀 ANDROID VIP BYPASS
      android: {
        priority: "high",
        notification: {
          channelId: "bhojn_urgent_channel",
          sound: "default"
        }
      },
      // 🍎 iPHONE VIP BYPASS
      apns: {
        payload: {
          aps: { sound: "default", contentAvailable: true }
        }
      }
    });
    console.log(`📣 VIP Broadcasted to ${tokens.length} students: ${title}`);
  } catch (e) {
    console.error(`🚨 Error broadcasting:`, e);
  }
}