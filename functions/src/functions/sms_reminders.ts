import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";

const atApiKeySecret = defineSecret("AT_API_KEY");
const atUsernameSecret = defineSecret("AT_USERNAME");

const db = () => admin.firestore();

export const sendDebtReminders = onSchedule(
  {
    schedule: "0 8 * * *", // 8 AM every day
    timeZone: "Africa/Nairobi",
    secrets: [atApiKeySecret, atUsernameSecret],
  },
  async () => {
    // Import Africa's Talking lazily to ensure environment variables are loaded
    const credentials = {
      apiKey: atApiKeySecret.value(),
      username: atUsernameSecret.value(),
    };
    const AfricasTalking = require("africastalking")(credentials);
    const sms = AfricasTalking.SMS;

    const now = admin.firestore.Timestamp.now();

    const customersSnap = await db()
      .collection("customers")
      .where("totalDebt", ">", 0)
      .get();

    if (customersSnap.empty) {
      console.log("No customers with outstanding debt found.");
      return;
    }

    const messagesToSend: { to: string; message: string }[] = [];

    customersSnap.docs.forEach((doc) => {
      const customer = doc.data();
      if (!customer.paymentDueDate) return;
      
      const dueDateTimestamp = customer.paymentDueDate as admin.firestore.Timestamp;
      const dueDate = dueDateTimestamp.toDate();

      const timeDiff = dueDate.getTime() - now.toDate().getTime();
      const daysUntilDue = Math.ceil(timeDiff / (1000 * 3600 * 24));

      let message = "";
      if (daysUntilDue === 3) {
        message = `Dear ${customer.fullName}, a friendly reminder that your outstanding balance of KES ${customer.totalDebt} is due in 3 days. - HardwareOS`;
      } else if (daysUntilDue <= 0) {
        // Daily overdue reminder
        message = `Dear ${customer.fullName}, your outstanding balance of KES ${customer.totalDebt} is overdue. Please make a payment as soon as possible. - HardwareOS`;
      }

      if (message !== "" && customer.phoneNumber) {
        let phone = customer.phoneNumber;
        if (phone.startsWith("0")) {
            phone = "+254" + phone.substring(1);
        } else if (!phone.startsWith("+")) {
            phone = "+" + phone; // Assumes country code is included without +
        }
        messagesToSend.push({
          to: phone,
          message,
        });
      }
    });

    if (messagesToSend.length > 0) {
      try {
        for (const msg of messagesToSend) {
            await sms.send({ to: [msg.to], message: msg.message });
            console.log(`Sent SMS to ${msg.to}`);
        }
      } catch (e) {
        console.error("Error sending SMS reminders:", e);
      }
    }
  }
);
