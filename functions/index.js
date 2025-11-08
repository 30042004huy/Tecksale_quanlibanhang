// functions/index.js
const { onValueCreated } = require("firebase-functions/v2/database");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onNewWebOrder = onValueCreated(
  {
    ref: "website_data/{userId}/orders/{orderId}",
    region: "us-central1", // ĐÃ ĐÚNG
  },
  async (event) => {
    const snapshot = event.data;
    const userId = event.params.userId;
    const orderId = event.params.orderId;
    const orderData = snapshot.val();

    if (!orderData || orderData.status !== "MoiDat") {
      return null;
    }

    logger.info(`New order detected: ${orderId} for user ${userId}`);

    const customerInfo = orderData.customerInfo || {};
    const customerName = customerInfo.name?.trim() || "Khách Web";
    const customerPhone = customerInfo.phone?.trim() || "N/A";

    const tokenSnapshot = await admin.database().ref(`nguoidung/${userId}/fcmToken`).get();
    if (!tokenSnapshot.exists()) {
      logger.warn(`No FCM token for user: ${userId}`);
      return null;
    }
    const fcmToken = tokenSnapshot.val().trim();

    const message = {
      token: fcmToken,
      notification: {
        title: "Bạn có đơn hàng mới!",
        body: `${customerName} - ${customerPhone}`,
      },
      data: {
        type: "new_web_order",
        orderId: orderId,
        title: "Bạn có đơn hàng mới!",
        body: `${customerName} - ${customerPhone}`,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel", // PHẢI KHỚP VỚI APP
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      logger.info("FCM sent successfully:", response);
      return null;
    } catch (error) {
      logger.error("FCM send failed:", error);
      if (error.code === "messaging/registration-token-not-registered") {
        await admin.database().ref(`nguoidung/${userId}/fcmToken`).remove();
      }
      return null;
    }
  }
);