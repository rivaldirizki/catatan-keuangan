import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { db } from '../config/database.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let isInitialized = false;
let messagingInstance = null;

function initFirebase() {
  if (isInitialized) return messagingInstance;

  try {
    const credPath = path.resolve(__dirname, '../../config/firebase-service-account.json');
    let serviceAccount = null;

    if (fs.existsSync(credPath)) {
      const fileData = fs.readFileSync(credPath, 'utf8');
      serviceAccount = JSON.parse(fileData);
    } else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    }

    if (serviceAccount && serviceAccount.project_id) {
      const app = initializeApp({
        credential: cert(serviceAccount)
      });
      isInitialized = true;
      messagingInstance = getMessaging(app);
      console.log(`[FCM] Firebase Admin successfully initialized for project: ${serviceAccount.project_id}`);
    } else {
      console.log('[FCM] Firebase service account not found. Push notifications will be simulated in standby.');
    }
  } catch (err) {
    console.warn('[FCM] Error initializing Firebase Admin:', err.message);
  }

  return messagingInstance;
}

// Inisialisasi saat startup
initFirebase();

export const fcmService = {
  isAvailable() {
    return isInitialized && messagingInstance !== null;
  },

  async registerDeviceToken(userId, fcmToken, platform = 'android') {
    if (!userId || !fcmToken) return false;
    await db.query(
      `INSERT INTO user_device_tokens (user_id, fcm_token, platform)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), platform = VALUES(platform), updated_at = NOW()`,
      [userId, fcmToken, platform]
    );
    return true;
  },

  async unregisterDeviceToken(fcmToken) {
    if (!fcmToken) return false;
    await db.query(`DELETE FROM user_device_tokens WHERE fcm_token = ?`, [fcmToken]);
    return true;
  },

  async getUserTokens(userIds) {
    if (!userIds || userIds.length === 0) return [];
    const placeholders = userIds.map(() => '?').join(',');
    const rows = await db.query(
      `SELECT fcm_token FROM user_device_tokens WHERE user_id IN (${placeholders})`,
      userIds
    );
    return Array.isArray(rows) ? rows.map(r => r.fcm_token) : [];
  },

  async sendMulticastNotification({ tokens, title, body, data = {} }) {
    if (!tokens || tokens.length === 0) return { successCount: 0, failureCount: 0 };
    const uniqueTokens = [...new Set(tokens.filter(t => typeof t === 'string' && t.trim().length > 0))];
    if (uniqueTokens.length === 0) return { successCount: 0, failureCount: 0 };

    const messaging = initFirebase();
    if (!messaging) {
      // Graceful fallback when Firebase credentials are not yet installed
      return { successCount: 0, failureCount: 0, simulated: true };
    }

    try {
      // Ensure all data payload fields are string
      const stringData = {};
      for (const [key, val] of Object.entries(data)) {
        stringData[key] = typeof val === 'string' ? val : JSON.stringify(val);
      }
      stringData.click_action = 'FLUTTER_NOTIFICATION_CLICK';

      const message = {
        tokens: uniqueTokens,
        notification: {
          title: title || 'Pesan Baru',
          body: body || 'Anda menerima pesan baru.',
        },
        data: stringData,
        android: {
          priority: 'high',
          notification: {
            channelId: 'linc_chat_channel_v2',
            priority: 'max',
            visibility: 'public',
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      };

      const response = await messaging.sendEachForMulticast(message);

      // Clean up invalid or expired tokens
      if (response.failureCount > 0) {
        const deadTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const code = resp.error.code;
            if (
              code === 'messaging/registration-token-not-registered' ||
              code === 'messaging/invalid-registration-token'
            ) {
              deadTokens.push(uniqueTokens[idx]);
            }
          }
        });

        if (deadTokens.length > 0) {
          const placeholders = deadTokens.map(() => '?').join(',');
          await db.query(`DELETE FROM user_device_tokens WHERE fcm_token IN (${placeholders})`, deadTokens);
        }
      }

      return {
        successCount: response.successCount,
        failureCount: response.failureCount,
      };
    } catch (err) {
      console.warn('[FCM] Error sending multicast notification:', err.message);
      return { successCount: 0, failureCount: uniqueTokens.length, error: err.message };
    }
  }
};
