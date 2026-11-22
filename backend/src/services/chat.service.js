import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { db } from '../config/database.js';

function generateChatCode() {
  return 'CHAT-' + crypto.randomBytes(4).toString('hex').toUpperCase();
}

export const ChatService = {
  async getUserChatCode(userId) {
    const users = await db.query('SELECT id, name, email, chat_invite_code FROM users WHERE id = ?', [userId]);
    if (!users || users.length === 0) {
      throw new Error('User tidak ditemukan');
    }
    const user = users[0];
    if (user.chat_invite_code) {
      return user.chat_invite_code;
    }
    const newCode = generateChatCode();
    await db.query('UPDATE users SET chat_invite_code = ? WHERE id = ?', [newCode, userId]);
    return newCode;
  },

  async getOrCreateFamilyRoom(familyId, userId) {
    if (!familyId) return null;
    const existingRooms = await db.query('SELECT * FROM chat_rooms WHERE type = "family" AND family_id = ?', [familyId]);
    let room;
    if (existingRooms && existingRooms.length > 0) {
      room = existingRooms[0];
    } else {
      const fams = await db.query('SELECT * FROM families WHERE id = ?', [familyId]);
      const famName = fams && fams.length > 0 ? fams[0].name : '';
      const insertRes = await db.query(
        'INSERT INTO chat_rooms (type, family_id, company_id, name, created_by) VALUES (?, ?, ?, ?, ?)',
        ['family', familyId, null, `Keluarga ${famName}`.trim(), userId]
      );
      room = {
        id: insertRes.insertId,
        type: 'family',
        family_id: familyId,
        company_id: null,
        name: `Keluarga ${famName}`.trim(),
        created_by: userId
      };
    }

    // Auto-sync members from users table
    const familyUsers = await db.query('SELECT id, role FROM users WHERE family_id = ?', [familyId]);
    for (const u of familyUsers) {
      const existingMember = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [room.id, u.id]);
      if (!existingMember || existingMember.length === 0) {
        await db.query(
          'INSERT INTO chat_members (room_id, user_id, role, status) VALUES (?, ?, ?, ?)',
          [room.id, u.id, u.role === 'admin' ? 'admin' : 'member', 'accepted']
        );
      } else if (existingMember[0].status !== 'accepted') {
        await db.query('UPDATE chat_members SET status = "accepted" WHERE id = ?', [existingMember[0].id]);
      }
    }

    return room;
  },

  async getOrCreateCompanyRoom(companyId, userId) {
    if (!companyId) return null;
    const existingRooms = await db.query('SELECT * FROM chat_rooms WHERE type = "company" AND company_id = ?', [companyId]);
    let room;
    if (existingRooms && existingRooms.length > 0) {
      room = existingRooms[0];
    } else {
      const comps = await db.query('SELECT * FROM companies WHERE id = ?', [companyId]);
      const compName = comps && comps.length > 0 ? comps[0].name : '';
      const insertRes = await db.query(
        'INSERT INTO chat_rooms (type, family_id, company_id, name, created_by) VALUES (?, ?, ?, ?, ?)',
        ['company', null, companyId, `Perusahaan ${compName}`.trim(), userId]
      );
      room = {
        id: insertRes.insertId,
        type: 'company',
        family_id: null,
        company_id: companyId,
        name: `Perusahaan ${compName}`.trim(),
        created_by: userId
      };
    }

    // Auto-sync members from users table
    const companyUsers = await db.query('SELECT id, role FROM users WHERE company_id = ?', [companyId]);
    for (const u of companyUsers) {
      const existingMember = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [room.id, u.id]);
      if (!existingMember || existingMember.length === 0) {
        await db.query(
          'INSERT INTO chat_members (room_id, user_id, role, status) VALUES (?, ?, ?, ?)',
          [room.id, u.id, u.role === 'admin' ? 'admin' : 'member', 'accepted']
        );
      } else if (existingMember[0].status !== 'accepted') {
        await db.query('UPDATE chat_members SET status = "accepted" WHERE id = ?', [existingMember[0].id]);
      }
    }

    return room;
  },

  async sendDirectInvite(senderUserId, targetInviteCode) {
    const cleanCode = (targetInviteCode || '').trim().toUpperCase();
    if (!cleanCode) {
      throw new Error('Kode undangan chat wajib diisi.');
    }

    const targetUsers = await db.query('SELECT id, name, email, chat_invite_code FROM users WHERE chat_invite_code = ?', [cleanCode]);
    if (!targetUsers || targetUsers.length === 0) {
      throw new Error('User tujuan tidak ditemukan. Periksa kembali kode undangan chat.');
    }

    const targetUser = targetUsers[0];
    if (targetUser.id === senderUserId) {
      throw new Error('Tidak dapat mengirim undangan ke diri sendiri.');
    }

    // Check existing direct rooms between sender and target
    const senderMemberships = await db.query('SELECT room_id, status FROM chat_members WHERE user_id = ?', [senderUserId]);
    for (const sm of senderMemberships) {
      const room = (await db.query('SELECT * FROM chat_rooms WHERE id = ?', [sm.room_id]))[0];
      if (room && room.type === 'direct') {
        const targetMember = (await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [room.id, targetUser.id]))[0];
        if (targetMember) {
          if (targetMember.status === 'accepted' && sm.status === 'accepted') {
            throw new Error('Obrolan dengan user ini sudah aktif.');
          }
          if (targetMember.status === 'pending' || sm.status === 'pending') {
            throw new Error('Undangan obrolan masih menunggu persetujuan.');
          }
        }
      }
    }

    // Create direct room
    const insertRoom = await db.query(
      'INSERT INTO chat_rooms (type, family_id, company_id, name, created_by) VALUES (?, ?, ?, ?, ?)',
      ['direct', null, null, null, senderUserId]
    );
    const roomId = insertRoom.insertId;

    // Sender is accepted
    await db.query(
      'INSERT INTO chat_members (room_id, user_id, role, status) VALUES (?, ?, ?, ?)',
      [roomId, senderUserId, 'admin', 'accepted']
    );

    // Target is pending
    const insertTargetMember = await db.query(
      'INSERT INTO chat_members (room_id, user_id, role, status) VALUES (?, ?, ?, ?)',
      [roomId, targetUser.id, 'member', 'pending']
    );

    return {
      room_id: roomId,
      invitation_id: insertTargetMember.insertId,
      target_user: {
        id: targetUser.id,
        name: targetUser.name,
        email: targetUser.email
      }
    };
  },

  async respondToInvitation(invitationId, userId, action) {
    if (!['accept', 'reject'].includes(action)) {
      throw new Error('Aksi tidak valid. Pilih "accept" atau "reject".');
    }

    const members = await db.query('SELECT * FROM chat_members WHERE id = ? AND user_id = ? AND status = "pending"', [invitationId, userId]);
    if (!members || members.length === 0) {
      throw new Error('Undangan tidak ditemukan atau sudah diproses.');
    }

    const invitation = members[0];
    const newStatus = action === 'accept' ? 'accepted' : 'rejected';
    await db.query('UPDATE chat_members SET status = ? WHERE id = ?', [newStatus, invitation.id]);

    return {
      success: true,
      action,
      room_id: invitation.room_id
    };
  },

  async getUserRooms(userId, familyId = null, companyId = null) {
    if (familyId) {
      await this.getOrCreateFamilyRoom(familyId, userId);
    }
    if (companyId) {
      await this.getOrCreateCompanyRoom(companyId, userId);
    }

    const memberships = await db.query('SELECT * FROM chat_members WHERE user_id = ? AND status = "accepted"', [userId]);
    const results = [];

    for (const mem of memberships) {
      const rooms = await db.query('SELECT * FROM chat_rooms WHERE id = ?', [mem.room_id]);
      if (!rooms || rooms.length === 0) continue;
      const room = rooms[0];

      let displayName = room.name;
      let otherUserName = null;
      let otherUserEmail = null;
      let otherMemberStatus = 'accepted';

      if (room.type === 'direct') {
        const otherMembers = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id != ?', [room.id, userId]);
        if (otherMembers && otherMembers.length > 0) {
          const otherMem = otherMembers[0];
          otherMemberStatus = otherMem.status;
          const otherUsers = await db.query('SELECT id, name, email FROM users WHERE id = ?', [otherMem.user_id]);
          if (otherUsers && otherUsers.length > 0) {
            displayName = otherUsers[0].name;
            otherUserName = otherUsers[0].name;
            otherUserEmail = otherUsers[0].email;
          }
        }
      }

      // Last message
      const lastMessages = await db.query('SELECT * FROM chat_messages WHERE room_id = ? ORDER BY id DESC LIMIT 1', [room.id]);
      const lastMsg = lastMessages && lastMessages.length > 0 ? lastMessages[0] : null;

      // Unread count
      const allMsgs = await db.query('SELECT id, user_id FROM chat_messages WHERE room_id = ?', [room.id]);
      const unreadCount = (allMsgs || []).filter(m => Number(m.id) > Number(mem.last_read_message_id || 0) && Number(m.user_id) !== Number(userId)).length;

      results.push({
        id: room.id,
        type: room.type,
        name: displayName || (room.type === 'direct' ? otherUserName : 'Ruang Obrolan'),
        other_user_name: otherUserName,
        other_user_email: otherUserEmail,
        other_member_status: otherMemberStatus,
        last_message: lastMsg ? lastMsg.message : null,
        last_message_type: lastMsg ? lastMsg.message_type : null,
        last_message_at: lastMsg ? lastMsg.created_at : room.created_at,
        unread_count: unreadCount,
        created_at: room.created_at
      });
    }

    results.sort((a, b) => new Date(b.last_message_at || b.created_at) - new Date(a.last_message_at || a.created_at));
    return results;
  },

  async getPendingInvitations(userId) {
    const pendingMemberships = await db.query('SELECT * FROM chat_members WHERE user_id = ? AND status = "pending"', [userId]);
    const invitations = [];

    for (const pm of pendingMemberships) {
      const room = (await db.query('SELECT * FROM chat_rooms WHERE id = ?', [pm.room_id]))[0];
      if (!room || room.type !== 'direct') continue;

      const inviterMemberships = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id != ?', [room.id, userId]);
      if (!inviterMemberships || inviterMemberships.length === 0) continue;

      const inviterUsers = await db.query('SELECT id, name, email, chat_invite_code FROM users WHERE id = ?', [inviterMemberships[0].user_id]);
      const inviter = inviterUsers && inviterUsers.length > 0 ? inviterUsers[0] : null;

      invitations.push({
        id: pm.id,
        room_id: pm.room_id,
        inviter_id: inviter ? inviter.id : null,
        inviter_name: inviter ? inviter.name : 'Pengguna',
        inviter_email: inviter ? inviter.email : '',
        created_at: pm.joined_at || pm.created_at || room.created_at
      });
    }

    return invitations;
  },

  async getRoomMessages(roomId, userId, afterId = null) {
    const membership = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [roomId, userId]);
    if (!membership || membership.length === 0 || membership[0].status !== 'accepted') {
      const err = new Error('Akses ditolak. Anda bukan anggota aktif ruang obrolan ini.');
      err.status = 403;
      throw err;
    }

    const acceptedMembers = await db.query('SELECT user_id, last_read_message_id FROM chat_members WHERE room_id = ? AND status = "accepted"', [roomId]);
    const otherMembers = (acceptedMembers || []).filter(m => Number(m.user_id) !== Number(userId));
    const N = otherMembers.length;

    let messages;
    if (afterId && Number(afterId) > 0) {
      messages = await db.query('SELECT * FROM chat_messages WHERE room_id = ? AND id > ? ORDER BY id ASC', [roomId, Number(afterId)]);
    } else {
      messages = await db.query('SELECT * FROM chat_messages WHERE room_id = ? ORDER BY id ASC', [roomId]);
    }

    const allUsers = await db.query('SELECT id, name FROM users');
    const userMap = new Map((allUsers || []).map(u => [u.id, u.name]));

    return (messages || []).map(msg => {
      let deliveryStatus = null;
      if (Number(msg.user_id) === Number(userId)) {
        if (N === 0) {
          deliveryStatus = 'read';
        } else {
          const R = otherMembers.filter(m => Number(m.last_read_message_id || 0) >= Number(msg.id)).length;
          if (N === 1) {
            deliveryStatus = R >= 1 ? 'read' : 'sent';
          } else {
            if (R === 0) {
              deliveryStatus = 'sent';
            } else if (R < N) {
              deliveryStatus = 'partially_read';
            } else {
              deliveryStatus = 'read';
            }
          }
        }
      }

      let parsedMetadata = msg.metadata;
      if (typeof parsedMetadata === 'string') {
        try {
          parsedMetadata = JSON.parse(parsedMetadata);
        } catch (_) {}
      }

      return {
        id: msg.id,
        room_id: msg.room_id,
        user_id: msg.user_id,
        sender_name: userMap.get(msg.user_id) || 'Pengguna',
        message: msg.message,
        message_type: msg.message_type || 'text',
        metadata: parsedMetadata,
        delivery_status: deliveryStatus,
        created_at: msg.created_at
      };
    });
  },

  async sendMessage(roomId, userId, message, messageType = 'text', metadata = null) {
    const membership = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [roomId, userId]);
    if (!membership || membership.length === 0 || membership[0].status !== 'accepted') {
      const err = new Error('Akses ditolak. Anda bukan anggota aktif ruang obrolan ini.');
      err.status = 403;
      throw err;
    }

    const rooms = await db.query('SELECT * FROM chat_rooms WHERE id = ?', [roomId]);
    if (!rooms || rooms.length === 0) {
      throw new Error('Ruang obrolan tidak ditemukan.');
    }
    const room = rooms[0];

    if (room.type === 'direct') {
      const otherMembers = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id != ?', [roomId, userId]);
      if (!otherMembers || otherMembers.length === 0 || otherMembers[0].status !== 'accepted') {
        const err = new Error('Tidak dapat mengirim pesan: Undangan chat belum diterima atau sudah ditolak.');
        err.status = 403;
        throw err;
      }
    }

    const cleanMsg = (message || '').trim();
    if (!cleanMsg && !metadata) {
      throw new Error('Pesan tidak boleh kosong.');
    }

    const metaStr = metadata ? (typeof metadata === 'string' ? metadata : JSON.stringify(metadata)) : null;
    const insertRes = await db.query(
      'INSERT INTO chat_messages (room_id, user_id, message, message_type, metadata) VALUES (?, ?, ?, ?, ?)',
      [roomId, userId, cleanMsg || 'Berbagi Finansial', messageType || 'text', metaStr]
    );

    const messageId = insertRes.insertId;

    // Sender immediately marks their own message as read
    await db.query(
      'UPDATE chat_members SET last_read_message_id = ?, last_read_at = CURRENT_TIMESTAMP WHERE room_id = ? AND user_id = ?',
      [messageId, roomId, userId]
    );

    const users = await db.query('SELECT id, name FROM users WHERE id = ?', [userId]);
    const senderName = users && users.length > 0 ? users[0].name : 'Pengguna';

    return {
      id: messageId,
      room_id: roomId,
      user_id: userId,
      sender_name: senderName,
      message: cleanMsg || 'Berbagi Finansial',
      message_type: messageType || 'text',
      metadata: metadata,
      delivery_status: 'sent',
      created_at: new Date().toISOString()
    };
  },

  async markRoomAsRead(roomId, userId, messageId = null) {
    const membership = await db.query('SELECT * FROM chat_members WHERE room_id = ? AND user_id = ?', [roomId, userId]);
    if (!membership || membership.length === 0 || membership[0].status !== 'accepted') {
      return { success: false };
    }

    let targetId = messageId ? Number(messageId) : 0;
    if (!targetId) {
      const msgs = await db.query('SELECT id FROM chat_messages WHERE room_id = ? ORDER BY id DESC LIMIT 1', [roomId]);
      if (msgs && msgs.length > 0) {
        targetId = Number(msgs[0].id);
      }
    }

    const currentLastRead = Number(membership[0].last_read_message_id || 0);
    const newLastRead = Math.max(currentLastRead, targetId);

    await db.query(
      'UPDATE chat_members SET last_read_message_id = ?, last_read_at = CURRENT_TIMESTAMP WHERE room_id = ? AND user_id = ?',
      [newLastRead, roomId, userId]
    );

    return { success: true, last_read_message_id: newLastRead };
  },

  async deleteMessage(messageId, userId) {
    const msgs = await db.query('SELECT * FROM chat_messages WHERE id = ?', [messageId]);
    if (!msgs || msgs.length === 0) {
      throw new Error('Pesan tidak ditemukan.');
    }
    const msg = msgs[0];

    // Must be the message author
    if (Number(msg.user_id) !== Number(userId)) {
      const err = new Error('Akses ditolak. Anda hanya dapat menghapus pesan Anda sendiri.');
      err.status = 403;
      throw err;
    }

    // If message has media metadata with file_url, delete physical file from server
    if (msg.metadata) {
      let meta = msg.metadata;
      if (typeof meta === 'string') {
        try { meta = JSON.parse(meta); } catch (_) {}
      }
      if (meta && meta.file_url) {
        try {
          const uploadsDir = path.resolve('backend/uploads');
          const relPath = meta.file_url.replace(/^\/?uploads\//, '');
          const absPath = path.join(uploadsDir, relPath);
          if (fs.existsSync(absPath)) {
            fs.unlinkSync(absPath);
          }
        } catch (_) {}
      }
    }

    await db.query('DELETE FROM chat_messages WHERE id = ?', [messageId]);
    return { success: true, deleted_message_id: Number(messageId) };
  }
};
