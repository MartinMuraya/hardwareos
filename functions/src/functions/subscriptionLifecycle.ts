import * as admin from "firebase-admin";
import { SECURE_FN_OPTS } from "../config/functionOptions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GRACE_PERIOD_DAYS } from "../config/planLimits";

const db = () => admin.firestore();

// -----------------------------------------------------------
// expireSubscriptions
// Runs daily at 1:00 AM Africa/Nairobi
// Moves expired subscriptions → grace_period → expired
// -----------------------------------------------------------
export const expireSubscriptions = onSchedule(
  {
    schedule: "0 1 * * *",
    timeZone: "Africa/Nairobi",
    maxInstances: 1,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    let batch = db().batch();
    let batchCount = 0;

    // 1. Find active subscriptions past their end date → grace_period
    const activeExpired = await db()
      .collection("businesses")
      .where("subscriptionStatus", "==", "active")
      .where("subscriptionEndsAt", "<=", now)
      .get();

    for (const doc of activeExpired.docs) {
      const data = doc.data();
      const graceEndsAt = new Date();
      graceEndsAt.setDate(graceEndsAt.getDate() + GRACE_PERIOD_DAYS);

      batch.update(doc.ref, {
        subscriptionStatus: "grace_period",
        gracePeriodEndsAt: admin.firestore.Timestamp.fromDate(graceEndsAt),
        updatedAt: now,
      });

      // Log event
      const histRef = db().collection("subscriptionHistory").doc();
      batch.set(histRef, {
        id: histRef.id,
        businessId: doc.id,
        businessName: data.name || "",
        eventType: "subscription_expired",
        description: `Subscription expired. Entered ${GRACE_PERIOD_DAYS}-day grace period.`,
        plan: data.plan,
        previousStatus: "active",
        newStatus: "grace_period",
        timestamp: now,
      });

      batchCount++;
      if (batchCount >= 400) {
        await batch.commit();
        batch = db().batch();
        batchCount = 0;
      }
    }

    // 2. Find grace_period businesses past their grace end date → expired
    const graceExpired = await db()
      .collection("businesses")
      .where("subscriptionStatus", "==", "grace_period")
      .where("gracePeriodEndsAt", "<=", now)
      .get();

    for (const doc of graceExpired.docs) {
      const data = doc.data();

      batch.update(doc.ref, {
        subscriptionStatus: "expired",
        gracePeriodEndsAt: null,
        updatedAt: now,
      });

      // Log event
      const histRef = db().collection("subscriptionHistory").doc();
      batch.set(histRef, {
        id: histRef.id,
        businessId: doc.id,
        businessName: data.name || "",
        eventType: "grace_period_ended",
        description: "Grace period ended. Subscription is now expired.",
        plan: data.plan,
        previousStatus: "grace_period",
        newStatus: "expired",
        timestamp: now,
      });

      batchCount++;
      if (batchCount >= 400) {
        await batch.commit();
        batch = db().batch();
        batchCount = 0;
      }
    }

    // 3. Find trial businesses past their trial end date → expired (free)
    const trialExpired = await db()
      .collection("businesses")
      .where("subscriptionStatus", "==", "trial")
      .where("trialEndsAt", "<=", now)
      .get();

    for (const doc of trialExpired.docs) {
      const data = doc.data();

      batch.update(doc.ref, {
        subscriptionStatus: "expired",
        updatedAt: now,
      });

      const histRef = db().collection("subscriptionHistory").doc();
      batch.set(histRef, {
        id: histRef.id,
        businessId: doc.id,
        businessName: data.name || "",
        eventType: "trial_ended",
        description: "Trial period ended.",
        plan: "free",
        previousStatus: "trial",
        newStatus: "expired",
        timestamp: now,
      });

      batchCount++;
      if (batchCount >= 400) {
        await batch.commit();
        batch = db().batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    // Update aggregate stats after expiry run
    await aggregateSubscriptionStats();
  }
);

// -----------------------------------------------------------
// sendRenewalReminders
// Runs daily at 8:00 AM Africa/Nairobi
// Sends reminders at 7, 3, 1, and 0 days before expiry
// Uses subscriptionReminders subcollection for dedup
// -----------------------------------------------------------
export const sendRenewalReminders = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Africa/Nairobi",
    maxInstances: 1,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const today = new Date();
    let batch = db().batch();
    let batchCount = 0;

    // Find businesses approaching expiry (active or grace_period)
    const businesses = await db()
      .collection("businesses")
      .where("subscriptionStatus", "in", ["active", "grace_period"])
      .get();

    for (const doc of businesses.docs) {
      const data = doc.data();
      const endsAt = data.subscriptionEndsAt?.toDate();
      if (!endsAt) continue;

      const daysUntilExpiry = Math.ceil(
        (endsAt.getTime() - today.getTime()) / (1000 * 60 * 60 * 24)
      );

      // Only remind at thresholds: 7, 3, 1, 0 days before
      const reminderDays = [7, 3, 1, 0];
      const matchedDays = reminderDays.filter((d) => daysUntilExpiry === d);

      for (const day of matchedDays) {
        // Check dedup — have we sent a reminder for this day already?
        const reminderId = `${doc.id}_renewal_${day}day`;
        const existingReminder = await db()
          .collection("subscriptionReminders")
          .doc(reminderId)
          .get();

        if (existingReminder.exists) continue;

        // Send reminder (store as notification for now)
        const notificationRef = db().collection("systemNotifications").doc();
        batch.set(notificationRef, {
          id: notificationRef.id,
          type: "renewal_reminder",
          businessId: doc.id,
          businessName: data.name || "",
          plan: data.plan,
          daysUntilExpiry: day,
          message:
            day === 0
              ? "Your subscription expires today! Renew now to avoid interruption."
              : day === 1
              ? "Your subscription expires tomorrow! Renew now to stay active."
              : `Your subscription expires in ${day} days. Please renew.`,
          createdAt: now,
          read: false,
        });

        // Record reminder
        batch.set(
          db().collection("subscriptionReminders").doc(reminderId),
          {
            id: reminderId,
            businessId: doc.id,
            reminderType: "renewal",
            daysBeforeExpiry: day,
            sentAt: now,
          }
        );

        // Log event
        const histRef = db().collection("subscriptionHistory").doc();
        batch.set(histRef, {
          id: histRef.id,
          businessId: doc.id,
          businessName: data.name || "",
          eventType: "renewal_reminder",
          description: `Renewal reminder sent (${day} day${day === 1 ? "" : "s"} before expiry).`,
          plan: data.plan,
          details: { daysBeforeExpiry: day },
          timestamp: now,
        });

        batchCount++;
      }

      if (batchCount >= 400) {
        await batch.commit();
        batch = db().batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    // Recover any stuck pending payments
    await recoverFailedPayments();
  }
);

// -----------------------------------------------------------
// recoverFailedPayments
// Finds pending subscriptions >10 min old → marks as failed
// Allows the user to retry
// -----------------------------------------------------------
async function recoverFailedPayments(): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  const tenMinutesAgo = admin.firestore.Timestamp.fromMillis(
    now.toMillis() - 10 * 60 * 1000
  );

  const pending = await db()
    .collection("subscriptions")
    .where("transactionStatus", "==", "pending")
    .where("createdAt", "<=", tenMinutesAgo)
    .get();

  if (pending.empty) return;

  const batch = db().batch();
  for (const doc of pending.docs) {
    const data = doc.data();
    batch.update(doc.ref, {
      transactionStatus: "failed",
      failureReason: "Payment timeout — user did not complete M-Pesa STK Push within 10 minutes.",
    });

    // Log event
    const histRef = db().collection("subscriptionHistory").doc();
    batch.set(histRef, {
      id: histRef.id,
      businessId: data.businessId,
      businessName: data.businessName || "",
      eventType: "payment_timeout",
      description: "Payment timed out after 10 minutes.",
      plan: data.plan,
      details: { checkoutRequestId: data.checkoutRequestId, amount: data.amount },
      timestamp: now,
    });
  }

  await batch.commit();
}

// -----------------------------------------------------------
// aggregateSubscriptionStats
// Computes subscription analytics and stores in a single doc
// for fast admin dashboard loading (< 2s target)
// -----------------------------------------------------------
async function aggregateSubscriptionStats(): Promise<void> {
  const now = new Date();
  
  // H-2: Use aggregation queries instead of full scans
  const [
    totalBusinessesSnap, activeSnap, trialSnap, expiredSnap, graceSnap, starterSnap, proSnap
  ] = await Promise.all([
    db().collection("businesses").count().get(),
    db().collection("businesses").where("subscriptionStatus", "==", "active").count().get(),
    db().collection("businesses").where("subscriptionStatus", "==", "trial").count().get(),
    db().collection("businesses").where("subscriptionStatus", "==", "expired").count().get(),
    db().collection("businesses").where("subscriptionStatus", "==", "grace_period").count().get(),
    db().collection("businesses").where("plan", "==", "starter").count().get(),
    db().collection("businesses").where("plan", "==", "pro").count().get(),
  ]);

  const totalBusinesses = totalBusinessesSnap.data().count;
  const activeSubscriptions = activeSnap.data().count;
  const trialAccounts = trialSnap.data().count;
  const expiredSubscriptions = expiredSnap.data().count;
  const gracePeriodAccounts = graceSnap.data().count;
  const starterAccounts = starterSnap.data().count;
  const proAccounts = proSnap.data().count;

  // M-4, M-8: Fetch actual plan prices and count only active subs for MRR
  let monthlyRecurringRevenue = 0;
  const plansSnap = await db().collection("subscription_plan_configs").get();
  for (const doc of plansSnap.docs) {
    const plan = doc.data();
    if (plan.priceKes > 0) {
      const activeSubsSnap = await db()
        .collection("businesses")
        .where("plan", "==", doc.id)
        .where("subscriptionStatus", "==", "active")
        .count()
        .get();
      monthlyRecurringRevenue += (plan.priceKes * activeSubsSnap.data().count);
    }
  }

  // Churn rate (last 30 days)
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const churnedLast30 = await db()
    .collection("subscriptionHistory")
    .where("eventType", "in", ["subscription_expired", "grace_period_ended", "trial_ended"])
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .count()
    .get();

  const churnCount = churnedLast30.data().count;
  const churnRate = totalBusinesses > 0 ? churnCount / totalBusinesses : 0;

  // Recovered last 30 days
  const recoveredLast30 = await db()
    .collection("subscriptionHistory")
    .where("eventType", "==", "subscription_renewed")
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .count()
    .get();
  const recoveryCount = recoveredLast30.data().count;

  // Payment success rate
  const successfulPaymentsSnap = await db().collection("subscriptions")
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .where("transactionStatus", "==", "completed")
    .count().get();
  
  const failedPaymentsSnap = await db().collection("subscriptions")
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .where("transactionStatus", "==", "failed")
    .count().get();

  const successfulPayments = successfulPaymentsSnap.data().count;
  const failedPayments = failedPaymentsSnap.data().count;
  const totalPaymentsSize = successfulPayments + failedPayments;

  const paymentSuccessRate = totalPaymentsSize > 0 ? successfulPayments / totalPaymentsSize : 1;

  // H-3: Dynamic historical metrics (append current month to existing data)
  const existingStatsSnap = await db().collection("subscriptionStats").doc("aggregate").get();
  let historicalMetrics: any[] = [];
  if (existingStatsSnap.exists) {
    historicalMetrics = existingStatsSnap.data()?.historicalMetrics || [];
  }
  
  const monthName = now.toLocaleString('default', { month: 'short' });
  // Remove existing entry for this month if it exists
  historicalMetrics = historicalMetrics.filter(m => m.month !== monthName);
  historicalMetrics.push({ month: monthName, mrr: monthlyRecurringRevenue, churnRate: churnRate });
  
  // Keep only the last 12 months
  if (historicalMetrics.length > 12) {
    historicalMetrics = historicalMetrics.slice(historicalMetrics.length - 12);
  }

  const stats = {
    computedAt: admin.firestore.Timestamp.fromDate(now),
    totalBusinesses,
    activeSubscriptions,
    trialAccounts,
    expiredSubscriptions,
    gracePeriodAccounts,
    starterAccounts,
    proAccounts,
    monthlyRecurringRevenue,
    churnRate,
    churnCount,
    recoveryCount,
    paymentSuccessRate,
    successfulPayments,
    failedPayments,
    totalPaymentsLast30: totalPaymentsSize,
    lastChurnPeriodEnd: admin.firestore.Timestamp.fromDate(thirtyDaysAgo),
    historicalMetrics,
  };

  await db().collection("subscriptionStats").doc("aggregate").set(stats);
}

// -----------------------------------------------------------
// getSubscriptionAnalytics
// Callable function for admin to fetch subscription stats
// -----------------------------------------------------------
export const getSubscriptionAnalytics = onCall(
  SECURE_FN_OPTS,
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Not logged in");

    // Check admin
    const adminSnap = await db()
      .collection("platformAdmins")
      .doc(request.auth.uid)
      .get();
    if (!adminSnap.exists) {
      throw new HttpsError("permission-denied", "Admin access required.");
    }

    // Return cached aggregate (computed by cron, under 2s)
    const statsDoc = await db()
      .collection("subscriptionStats")
      .doc("aggregate")
      .get();

    if (!statsDoc.exists) {
      // Compute on demand
      await aggregateSubscriptionStats();
      const freshDoc = await db()
        .collection("subscriptionStats")
        .doc("aggregate")
        .get();
      return freshDoc.data() || {};
    }

    return statsDoc.data();
  }
);

// -----------------------------------------------------------
// checkSubscriptionHealth
// Monitors for anomalies: high failure rate, expiry spikes
// Creates admin system notifications when thresholds exceeded
// -----------------------------------------------------------
export const checkSubscriptionHealth = onSchedule(
  {
    schedule: "0 6 * * *",
    timeZone: "Africa/Nairobi",
    maxInstances: 1,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const twentyFourHoursAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 24 * 60 * 60 * 1000
    );
    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 7 * 24 * 60 * 60 * 1000
    );

    const alerts: string[] = [];

    // 1. Check payment failure rate in last 24h
    const recentPayments = await db()
      .collection("subscriptions")
      .where("createdAt", ">=", twentyFourHoursAgo)
      .get();

    let recentSuccess = 0;
    let recentFailed = 0;
    for (const doc of recentPayments.docs) {
      const status = doc.data().transactionStatus;
      if (status === "completed") recentSuccess++;
      if (status === "failed" || status === "pending") recentFailed++;
    }

    const totalRecent = recentSuccess + recentFailed;
    if (totalRecent > 5) {
      const failureRate = recentFailed / totalRecent;
      if (failureRate > 0.5) {
        alerts.push(
          `High payment failure rate: ${(failureRate * 100).toFixed(0)}% (${recentFailed}/${totalRecent} failed) in last 24h.`
        );
      }
    }

    // 2. Check expiry spike in last 7 days
    const recentExpiries = await db()
      .collection("subscriptionHistory")
      .where("eventType", "in", ["subscription_expired", "grace_period_ended", "trial_ended"])
      .where("timestamp", ">=", sevenDaysAgo)
      .get();

    if (recentExpiries.size > 50) {
      alerts.push(
        `High churn detected: ${recentExpiries.size} subscriptions expired in the last 7 days.`
      );
    }

    // 3. Check grace period backlog
    const gracePeriodCount = await db()
      .collection("businesses")
      .where("subscriptionStatus", "==", "grace_period")
      .count()
      .get();
    const graceCount = gracePeriodCount.data().count;

    if (graceCount > 20) {
      alerts.push(
        `${graceCount} businesses are in grace period and at risk of expiry.`
      );
    }

    // 4. Create notifications for each alert
    if (alerts.length > 0) {
      const batch = db().batch();
      for (const alert of alerts) {
        const ref = db().collection("systemNotifications").doc();
        batch.set(ref, {
          id: ref.id,
          type: "health_alert",
          severity: "warning",
          message: alert,
          createdAt: now,
          read: false,
        });
      }
      await batch.commit();
    }
  }
);
