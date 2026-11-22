import test from 'node:test';
import assert from 'node:assert/strict';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { FamilyService } from '../src/services/family.service.js';
import { CompanyService } from '../src/services/company.service.js';
import { ChatService } from '../src/services/chat.service.js';

test('💬 ChatService Test Suite', async (t) => {
  if (db.mock && typeof db.mock.reset === 'function') {
    db.mock.reset();
  }

  // Register real test users
  const rand = Math.floor(Math.random() * 100000);
  const u1Res = await AuthService.register('Alice', `alice_${rand}@chat.test`, 'password123');
  const u2Res = await AuthService.register('Bob', `bob_${rand}@chat.test`, 'password123');
  const u3Res = await AuthService.register('Charlie', `charlie_${rand}@chat.test`, 'password123');
  const u4Res = await AuthService.register('David', `david_${rand}@chat.test`, 'password123');

  const user1 = u1Res.user;
  const user2 = u2Res.user;
  const user3 = u3Res.user;
  const user4 = u4Res.user;

  // Setup Family: Alice creates, Bob and Charlie join
  const family = await FamilyService.createFamily(user1.id, 'Keluarga Bahagia');
  await FamilyService.joinFamily(user2.id, family.invite_code);
  await FamilyService.joinFamily(user3.id, family.invite_code);

  // Setup Company: Alice creates, Charlie joins
  const company = await CompanyService.createCompany(user1.id, 'PT Sejahtera Abadi');
  await CompanyService.joinCompany(user3.id, company.invite_code);

  let aliceCode, bobCode, davidCode;

  await t.test('1. Should generate and fetch personal chat invite code', async () => {
    aliceCode = await ChatService.getUserChatCode(user1.id);
    bobCode = await ChatService.getUserChatCode(user2.id);
    davidCode = await ChatService.getUserChatCode(user4.id);

    assert.ok(aliceCode.startsWith('CHAT-'));
    assert.ok(bobCode.startsWith('CHAT-'));
    assert.ok(davidCode.startsWith('CHAT-'));
    assert.equal(aliceCode.length, 13); // 'CHAT-' (5) + 8 hex chars = 13
    assert.notEqual(aliceCode, bobCode);

    // Fetching again should return identical code
    const reAliceCode = await ChatService.getUserChatCode(user1.id);
    assert.equal(reAliceCode, aliceCode);
  });

  let familyRoom;
  await t.test('2. Should create and auto-sync family chat room', async () => {
    familyRoom = await ChatService.getOrCreateFamilyRoom(family.id, user1.id);
    assert.ok(familyRoom);
    assert.equal(familyRoom.type, 'family');
    assert.equal(familyRoom.family_id, family.id);

    // Verify all 3 family members (Alice, Bob, Charlie) were added as accepted members
    const members = await db.query('SELECT * FROM chat_members WHERE room_id = ?', [familyRoom.id]);
    assert.equal(members.length, 3);
    assert.ok(members.every(m => m.status === 'accepted'));
  });

  let companyRoom;
  await t.test('3. Should create and auto-sync company chat room', async () => {
    companyRoom = await ChatService.getOrCreateCompanyRoom(company.id, user1.id);
    assert.ok(companyRoom);
    assert.equal(companyRoom.type, 'company');
    assert.equal(companyRoom.company_id, company.id);

    // Verify members of company (Alice and Charlie) are present
    const members = await db.query('SELECT * FROM chat_members WHERE room_id = ?', [companyRoom.id]);
    assert.equal(members.length, 2);
    assert.ok(members.every(m => m.status === 'accepted'));
  });

  let directRoomId, directInvitationId;
  await t.test('4. Should send direct chat invite using invite code', async () => {
    // Attempt self-invite should fail
    await assert.rejects(
      async () => ChatService.sendDirectInvite(user1.id, aliceCode),
      /Tidak dapat mengirim undangan ke diri sendiri/
    );

    // Attempt invalid code should fail
    await assert.rejects(
      async () => ChatService.sendDirectInvite(user1.id, 'CHAT-INVALID'),
      /User tujuan tidak ditemukan/
    );

    // Alice invites David
    const inviteRes = await ChatService.sendDirectInvite(user1.id, davidCode);
    assert.ok(inviteRes.room_id);
    assert.ok(inviteRes.invitation_id);
    assert.equal(inviteRes.target_user.email, user4.email);
    directRoomId = inviteRes.room_id;
    directInvitationId = inviteRes.invitation_id;

    // Verify Alice is 'accepted' and David is 'pending'
    const aliceMember = (await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [directRoomId, user1.id]))[0];
    const davidMember = (await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [directRoomId, user4.id]))[0];
    assert.equal(aliceMember.status, 'accepted');
    assert.equal(davidMember.status, 'pending');

    // Duplicate invite while pending should be rejected
    await assert.rejects(
      async () => ChatService.sendDirectInvite(user1.id, davidCode),
      /Undangan obrolan masih menunggu persetujuan/
    );
  });

  await t.test('5. Should block sending message when direct invitation is still pending', async () => {
    await assert.rejects(
      async () => ChatService.sendMessage(directRoomId, user1.id, 'Halo David!'),
      /Undangan chat belum diterima/
    );
  });

  await t.test('6. Should list pending invitations for recipient and allow accept', async () => {
    const davidInvitations = await ChatService.getPendingInvitations(user4.id);
    assert.equal(davidInvitations.length, 1);
    assert.equal(davidInvitations[0].id, directInvitationId);
    assert.equal(davidInvitations[0].inviter_name, 'Alice');

    // David accepts
    const acceptRes = await ChatService.respondToInvitation(directInvitationId, user4.id, 'accept');
    assert.equal(acceptRes.success, true);
    assert.equal(acceptRes.action, 'accept');

    // Verify David is now accepted
    const davidMember = (await db.query('SELECT * FROM chat_members WHERE id = ?', [directInvitationId]))[0];
    assert.equal(davidMember.status, 'accepted');
  });

  let directMsg1;
  await t.test('7. Direct Chat receipts: sent (centang 1) -> read (centang 2 biru)', async () => {
    // Alice sends a message to David
    directMsg1 = await ChatService.sendMessage(directRoomId, user1.id, 'Halo David, apa kabar?');
    assert.ok(directMsg1.id);
    assert.equal(directMsg1.delivery_status, 'sent');

    // Alice views messages: should show 'sent' (centang 1) because David hasn't read it yet
    const msgsForAlice = await ChatService.getRoomMessages(directRoomId, user1.id);
    assert.equal(msgsForAlice.length, 1);
    assert.equal(msgsForAlice[0].delivery_status, 'sent');

    // David views messages (incoming message has delivery_status null)
    const msgsForDavid = await ChatService.getRoomMessages(directRoomId, user4.id);
    assert.equal(msgsForDavid.length, 1);
    assert.equal(msgsForDavid[0].delivery_status, null);

    // David marks room as read
    await ChatService.markRoomAsRead(directRoomId, user4.id, directMsg1.id);

    // Alice views messages now: should show 'read' (centang 2 biru)
    const msgsForAliceAfterRead = await ChatService.getRoomMessages(directRoomId, user1.id);
    assert.equal(msgsForAliceAfterRead[0].delivery_status, 'read');
  });

  await t.test('8. Group Chat receipts: sent (1) -> partially_read (2 abu-abu) -> read (2 biru)', async () => {
    // Alice sends a message to Family group (Alice, Bob, Charlie)
    const familyMsg = await ChatService.sendMessage(
      familyRoom.id,
      user1.id,
      'Pengeluaran belanja bulanan sudah dicatat ya!',
      'financial_share',
      { amount: 500000, category: 'Belanja Dapur' }
    );
    assert.ok(familyMsg.id);

    // Initially unread by others -> sent (centang 1)
    let msgs = await ChatService.getRoomMessages(familyRoom.id, user1.id);
    let myMsg = msgs.find(m => m.id === familyMsg.id);
    assert.equal(myMsg.delivery_status, 'sent');
    assert.equal(myMsg.message_type, 'financial_share');
    assert.equal(myMsg.metadata.amount, 500000);

    // Bob reads the message -> partially_read (centang 2 abu-abu)
    await ChatService.markRoomAsRead(familyRoom.id, user2.id, familyMsg.id);
    msgs = await ChatService.getRoomMessages(familyRoom.id, user1.id);
    myMsg = msgs.find(m => m.id === familyMsg.id);
    assert.equal(myMsg.delivery_status, 'partially_read');

    // Charlie reads the message -> read (centang 2 biru, because all other active members read it)
    await ChatService.markRoomAsRead(familyRoom.id, user3.id, familyMsg.id);
    msgs = await ChatService.getRoomMessages(familyRoom.id, user1.id);
    myMsg = msgs.find(m => m.id === familyMsg.id);
    assert.equal(myMsg.delivery_status, 'read');
  });

  await t.test('9. BOLA / IDOR protection: stranger cannot read or send to room', async () => {
    // David is not in familyRoom
    await assert.rejects(
      async () => ChatService.getRoomMessages(familyRoom.id, user4.id),
      /Akses ditolak/
    );

    await assert.rejects(
      async () => ChatService.sendMessage(familyRoom.id, user4.id, 'Penyusup!'),
      /Akses ditolak/
    );
  });

  let imageMsg;
  await t.test('10. Should send and retrieve media messages (image, video, file)', async () => {
    imageMsg = await ChatService.sendMessage(
      directRoomId,
      user1.id,
      'Foto struk pembayaran',
      'image',
      {
        file_url: '/uploads/chat/sample-struk.jpg',
        file_name: 'sample-struk.jpg',
        file_size: 154000,
        mime_type: 'image/jpeg'
      }
    );

    assert.ok(imageMsg.id);
    assert.equal(imageMsg.message_type, 'image');
    assert.equal(imageMsg.metadata.file_name, 'sample-struk.jpg');

    const msgs = await ChatService.getRoomMessages(directRoomId, user1.id);
    const retrieved = msgs.find(m => m.id === imageMsg.id);
    assert.ok(retrieved);
    assert.equal(retrieved.message_type, 'image');
    assert.equal(retrieved.metadata.file_url, '/uploads/chat/sample-struk.jpg');
  });

  await t.test('11. Should delete message and reject deletion by unauthorized user', async () => {
    // David tries to delete Alice's message -> rejected 403
    await assert.rejects(
      async () => ChatService.deleteMessage(imageMsg.id, user4.id),
      /Akses ditolak/
    );

    // Alice deletes her own message -> success
    const delRes = await ChatService.deleteMessage(imageMsg.id, user1.id);
    assert.equal(delRes.success, true);
    assert.equal(delRes.deleted_message_id, imageMsg.id);

    // Verify it is no longer in the room
    const msgsAfterDelete = await ChatService.getRoomMessages(directRoomId, user1.id);
    assert.ok(!msgsAfterDelete.some(m => m.id === imageMsg.id));
  });
});
