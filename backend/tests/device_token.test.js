import test from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { fcmService } from '../src/services/fcm.service.js';

test('🔔 FCM Service & Device Token Suite', async (t) => {
  const rand = Math.floor(Math.random() * 100000);
  const uRes = await AuthService.register('FCM Tester', `fcm_${rand}@test.com`, 'password123');
  const user = uRes.user;

  const testToken = `fcm_test_token_${rand}_sample`;

  await t.test('1. Register new device token', async () => {
    const success = await fcmService.registerDeviceToken(user.id, testToken, 'android');
    assert.equal(success, true);

    const tokens = await fcmService.getUserTokens([user.id]);
    assert.ok(tokens.includes(testToken));
  });

  await t.test('2. Updating existing token should succeed with ON DUPLICATE KEY UPDATE', async () => {
    const success = await fcmService.registerDeviceToken(user.id, testToken, 'android');
    assert.equal(success, true);

    const tokens = await fcmService.getUserTokens([user.id]);
    assert.equal(tokens.filter(t => t === testToken).length, 1);
  });

  await t.test('3. sendMulticastNotification works gracefully in standby mode', async () => {
    const res = await fcmService.sendMulticastNotification({
      tokens: [testToken],
      title: 'Uji Push Notification',
      body: 'Ini adalah tes notifikasi FCM.',
      data: { type: 'test' }
    });

    assert.ok(typeof res === 'object');
    // Either simulated (without credentials) or sent
    assert.ok('successCount' in res || res.simulated === true);
  });

  await t.test('4. Unregister device token', async () => {
    const success = await fcmService.unregisterDeviceToken(testToken);
    assert.equal(success, true);

    const tokens = await fcmService.getUserTokens([user.id]);
    assert.ok(!tokens.includes(testToken));
  });

  // Cleanup
  await db.query('DELETE FROM user_device_tokens WHERE fcm_token = ?', [testToken]);
});
