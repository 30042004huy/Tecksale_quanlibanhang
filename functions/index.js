const functions = require("firebase-functions");
const { onValueCreated } = require("firebase-functions/v2/database");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch"); // Đảm bảo bạn đã chạy: npm install node-fetch@2

admin.initializeApp();

// ===================================================================
// FUNCTION 1: GỬI THÔNG BÁO (Code cũ của bạn, giữ nguyên)
// ===================================================================
exports.onNewWebOrder = onValueCreated(
  {
    ref: "website_data/{userId}/orders/{orderId}",
    region: "us-central1",
  },
  async (event) => {
    // ... (Toàn bộ code gửi thông báo của bạn giữ nguyên) ...
    const snapshot = event.data;
    const userId = event.params.userId;
    const orderId = event.params.orderId;
    const orderData = snapshot.val();

    if (!orderData || orderData.status !== "MoiDat") {
      return null;
    }
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
      data: { type: "new_web_order", orderId: orderId, title: "Bạn có đơn hàng mới!", body: `${customerName} - ${customerPhone}`},
      android: { priority: "high", notification: { channelId: "high_importance_channel", sound: "default" }},
      apns: { payload: { aps: { sound: "default", badge: 1 }}},
    };
    try {
      await admin.messaging().send(message);
      logger.info("FCM sent successfully");
    } catch (error) {
      logger.error("FCM send failed:", error);
      if (error.code === "messaging/registration-token-not-registered") {
        await admin.database().ref(`nguoidung/${userId}/fcmToken`).remove();
      }
    }
    return null;
  }
);

// ===================================================================
// FUNCTION 2: TẠO ẢNH HÓA ĐƠN (Nâng cấp: Nhận JSON, tạo HTML)
// ===================================================================

// Hàm trợ giúp: Tự tạo HTML từ JSON
function buildHtmlFromInvoiceData(invoiceData) {
  // Lấy dữ liệu từ JSON (tên biến phải khớp với app Flutter)
  const shopName = invoiceData.shopName || "TeckSale";
  const shopPhone = invoiceData.shopPhone || "";
  const shopAddress = invoiceData.shopAddress || "";
  const customerName = invoiceData.customerName || "Khách lẻ";
  const customerPhone = invoiceData.customerPhone || "";
  const items = invoiceData.items || [];
  const totalPayment = invoiceData.totalPayment || 0;
  
  // Định dạng tiền tệ
  const formatter = new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' });
  
  // Tạo các hàng trong bảng sản phẩm
  let itemsHtml = '';
  items.forEach(item => {
    itemsHtml += `
      <tr>
        <td>${item.name}</td>
        <td>${item.quantity}</td>
        <td>${formatter.format(item.unitPrice)}</td>
        <td>${formatter.format(item.quantity * item.unitPrice)}</td>
      </tr>
    `;
  });

  // Đây là code HTML và CSS cho hóa đơn
  const html = `
    <html>
    <head>
      <style>
        body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; width: 400px; border: 1px solid #eee; box-shadow: 0 0 10px rgba(0, 0, 0, 0.15); padding: 20px; margin: auto; }
        h1 { font-size: 24px; color: #333; text-align: center; }
        p { font-size: 14px; line-height: 1.6; }
        .info { margin-bottom: 20px; }
        .info p { margin: 0; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border-bottom: 1px solid #ddd; padding: 8px; text-align: left; font-size: 14px; }
        th { background-color: #f9f9f9; }
        .total { font-weight: bold; font-size: 16px; text-align: right; margin-top: 20px; }
      </style>
    </head>
    <body>
      <h1>${shopName}</h1>
      <div class="info">
        <p><strong>Điện thoại:</strong> ${shopPhone}</p>
        <p><strong>Địa chỉ:</strong> ${shopAddress}</p>
      </div>
      <h2>Hóa đơn bán hàng</h2>
      <div class="info">
        <p><strong>Khách hàng:</strong> ${customerName}</p>
        <p><strong>SĐT:</strong> ${customerPhone}</p>
      </div>
      <table>
        <thead>
          <tr>
            <th>Sản phẩm</th>
            <th>SL</th>
            <th>Đơn giá</th>
            <th>Thành tiền</th>
          </tr>
        </thead>
        <tbody>
          ${itemsHtml}
        </tbody>
      </table>
      <p class="total">Tổng cộng: ${formatter.format(totalPayment)}</p>
    </body>
    </html>
  `;
  
  return html;
}

exports.taoAnhHoaDon = functions.https.onCall(async (data, context) => {
  // 1. Lấy JSON từ app Flutter
  const invoiceData = data.invoiceData;
  if (!invoiceData) {
    throw new functions.https.HttpsError("invalid-argument", "Không có dữ liệu hóa đơn (invoiceData).");
  }

  // 2. Tự tạo HTML/CSS
  const html = buildHtmlFromInvoiceData(invoiceData);
  const css = ""; // Chúng ta đã nhúng CSS vào HTML ở trên

  // 3. Lấy API key
  const USER_ID = "01K9J4X7VS6WPERHR89E4KPMQ";
  const API_KEY = "019a644e-9fbb-79a2-a504-8e24a369a460";
  const authHeader = "Basic " + Buffer.from(USER_ID + ":" + API_KEY).toString("base64");

  try {
    // 4. Gọi API
    const response = await fetch("https://hcti.io/v1/image", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": authHeader },
      body: JSON.stringify({ html: html, css: css }),
    });
    const jsonResponse = await response.json();

    // 5. Trả về link ảnh
    if (jsonResponse.url) {
      return { imageUrl: jsonResponse.url };
    } else {
      logger.error("Lỗi từ HCTI API:", jsonResponse);
      throw new functions.https.HttpsError("internal", "Không thể tạo ảnh từ API.");
    }
  } catch (error) {
    logger.error("Lỗi khi gọi HCTI:", error);
    throw new functions.https.HttpsError("internal", "Lỗi Cloud Function.");
  }
});