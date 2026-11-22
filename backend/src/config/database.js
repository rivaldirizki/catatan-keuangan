import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
dotenv.config();

const DB_CONFIG = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'finance_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  decimalNumbers: true
};

const isRunningTest = process.env.NODE_ENV === 'test' || process.argv.some(a => a.includes('tests') || a.includes('--test'));
let pool = null;
let mysqlUnavailableInTest = false;

export async function getPool() {
  if (isRunningTest && mysqlUnavailableInTest) {
    throw new Error('MySQL unavailable in test environment');
  }

  if (!pool) {
    try {
      const initConn = await mysql.createConnection({
        host: DB_CONFIG.host,
        port: DB_CONFIG.port,
        user: DB_CONFIG.user,
        password: DB_CONFIG.password,
        connectTimeout: isRunningTest ? 1000 : 5000
      });
      await initConn.query(`CREATE DATABASE IF NOT EXISTS \`${DB_CONFIG.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
      await initConn.query(`USE \`${DB_CONFIG.database}\`;`);
      try {
        await initConn.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS company_id INT NULL AFTER family_id;`);
        await initConn.query(`ALTER TABLE wallets ADD COLUMN IF NOT EXISTS company_id INT NULL AFTER family_id;`);
        await initConn.query(`ALTER TABLE transactions ADD COLUMN IF NOT EXISTS company_id INT NULL AFTER family_id;`);
        await initConn.query(`ALTER TABLE transactions ADD COLUMN IF NOT EXISTS project_id INT NULL AFTER company_id;`);
        await initConn.query(`ALTER TABLE debts ADD COLUMN IF NOT EXISTS company_id INT NULL AFTER family_id;`);
        await initConn.query(`ALTER TABLE debts ADD COLUMN IF NOT EXISTS installments_count INT NOT NULL DEFAULT 1 AFTER remaining_amount;`);
        await initConn.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS chat_invite_code VARCHAR(20) NULL;`);
        try {
          await initConn.query(`ALTER TABLE debts MODIFY COLUMN scope ENUM('personal', 'family', 'company') DEFAULT 'personal';`);
        } catch (_) {}
        await initConn.query(`
          CREATE TABLE IF NOT EXISTS chat_rooms (
            id INT AUTO_INCREMENT PRIMARY KEY,
            type ENUM('family', 'company', 'direct') NOT NULL,
            family_id INT NULL,
            company_id INT NULL,
            name VARCHAR(255) NULL,
            created_by INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          );
        `);
        await initConn.query(`
          CREATE TABLE IF NOT EXISTS chat_members (
            id INT AUTO_INCREMENT PRIMARY KEY,
            room_id INT NOT NULL,
            user_id INT NOT NULL,
            role ENUM('admin', 'member') DEFAULT 'member',
            status ENUM('pending', 'accepted', 'rejected') DEFAULT 'accepted',
            last_read_message_id INT NOT NULL DEFAULT 0,
            last_read_at TIMESTAMP NULL,
            joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          );
        `);
        await initConn.query(`
          CREATE TABLE IF NOT EXISTS chat_messages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            room_id INT NOT NULL,
            user_id INT NOT NULL,
            message TEXT NOT NULL,
            message_type ENUM('text', 'system', 'financial_share', 'image', 'video', 'file') DEFAULT 'text',
            metadata JSON NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          );
        `);
        try {
          await initConn.query(`ALTER TABLE chat_messages MODIFY COLUMN message_type ENUM('text', 'system', 'financial_share', 'image', 'video', 'file') DEFAULT 'text';`);
        } catch (_) {}
      } catch (_) {}
      await initConn.end();

      pool = mysql.createPool(DB_CONFIG);
    } catch (err) {
      if (isRunningTest) {
        mysqlUnavailableInTest = true;
      } else {
        console.error('[MySQL Error] Gagal menyambung ke MySQL server:', err.message);
      }
      throw err;
    }
  }
  return pool;
}

// In-memory mock relational store for isolated tests
class MockDatabase {
  constructor() {
    this.tables = {
      users: [],
      families: [],
      companies: [],
      projects: [],
      wallets: [],
      categories: [],
      transactions: [],
      savings: [],
      debts: [],
      chat_rooms: [],
      chat_members: [],
      chat_messages: []
    };
    this.autoIncrement = {
      users: 1,
      families: 1,
      companies: 1,
      projects: 1,
      wallets: 1,
      categories: 1,
      transactions: 1,
      savings: 1,
      debts: 1,
      chat_rooms: 1,
      chat_members: 1,
      chat_messages: 1
    };
    this.seedDefaultCategories();
  }

  seedDefaultCategories() {
    this.tables.categories = [
      { id: 1, user_id: null, name: 'Gaji', type: 'income', color: '#10B981', icon: 'briefcase' },
      { id: 2, user_id: null, name: 'Investasi & Usaha', type: 'income', color: '#059669', icon: 'trending-up' },
      { id: 3, user_id: null, name: 'Bonus & Hadiah', type: 'income', color: '#3B82F6', icon: 'gift' },
      { id: 4, user_id: null, name: 'Makanan & Minuman', type: 'expense', color: '#EF4444', icon: 'utensils' },
      { id: 5, user_id: null, name: 'Transportasi', type: 'expense', color: '#F59E0B', icon: 'car' },
      { id: 6, user_id: null, name: 'Tagihan & Utilitas', type: 'expense', color: '#6366F1', icon: 'receipt' },
      { id: 7, user_id: null, name: 'Belanja Kebutuhan', type: 'expense', color: '#EC4899', icon: 'shopping-bag' },
      { id: 8, user_id: null, name: 'Kesehatan', type: 'expense', color: '#14B8A6', icon: 'heart-pulse' },
      { id: 9, user_id: null, name: 'Pendidikan', type: 'expense', color: '#8B5CF6', icon: 'graduation-cap' },
      { id: 10, user_id: null, name: 'Hiburan', type: 'expense', color: '#F97316', icon: 'gamepad-2' },
      { id: 11, user_id: null, name: 'Lain-lain', type: 'expense', color: '#64748B', icon: 'tag' }
    ];
    this.autoIncrement.categories = 12;
  }

  hasTable(tableName) {
    return Object.prototype.hasOwnProperty.call(this.tables, tableName);
  }

  reset() {
    for (const key of Object.keys(this.tables)) {
      this.tables[key] = [];
      this.autoIncrement[key] = 1;
    }
    this.seedDefaultCategories();
  }

  async query(sql, params = []) {
    const cleanSql = sql.trim();
    if (/^SELECT\s+1/i.test(cleanSql)) {
      return [{ val: 1 }];
    }
    if (/^SHOW\s+TABLES/i.test(cleanSql)) {
      return Object.keys(this.tables).map(t => ({ [`Tables_in_finance_db`]: t }));
    }

    const insertMatch = cleanSql.match(/^INSERT\s+INTO\s+([a-zA-Z0-9_]+)\s*\(([^)]+)\)\s*VALUES\s*\(([^)]+)\)/i);
    if (insertMatch) {
      const table = insertMatch[1].toLowerCase();
      if (!this.tables[table]) {
        this.tables[table] = [];
        this.autoIncrement[table] = 1;
      }
      const columns = insertMatch[2].split(',').map(c => c.trim().replace(/[`"']/g, ''));
      const id = this.autoIncrement[table]++;
      const row = { id, created_at: new Date().toISOString() };
      if (table === 'chat_members') {
        row.last_read_message_id = 0;
        row.status = 'accepted';
        row.joined_at = new Date().toISOString();
      }
      columns.forEach((col, idx) => {
        row[col] = params[idx] !== undefined ? params[idx] : null;
      });
      this.tables[table].push(row);
      return { insertId: id, affectedRows: 1 };
    }

    const selectMatch = cleanSql.match(/^SELECT\s+(.+?)\s+FROM\s+([a-zA-Z0-9_]+)(?:\s+[a-zA-Z0-9_]+)?((?:\s+LEFT\s+JOIN\s+[a-zA-Z0-9_]+(?:\s+[a-zA-Z0-9_]+)?\s+ON\s+[^\s]+\s*=\s*[^\s]+)*)(?:\s+WHERE\s+(.+?))?(?:\s+ORDER\s+BY\s+(.+?))?(?:\s+LIMIT\s+(\d+))?$/is);
    if (selectMatch) {
      const table = selectMatch[2].toLowerCase();
      let rows = (this.tables[table] || []).map(r => ({ ...r }));
      const joinClause = selectMatch[3] ? selectMatch[3] : '';
      if (joinClause) {
        if (/LEFT\s+JOIN\s+users/i.test(joinClause) && this.tables.users) {
          rows.forEach(r => {
            const u = this.tables.users.find(user => user.id === r.user_id);
            if (u) r.user_name = u.name;
          });
        }
        if (/LEFT\s+JOIN\s+wallets/i.test(joinClause) && this.tables.wallets) {
          rows.forEach(r => {
            const w = this.tables.wallets.find(wal => wal.id === r.wallet_id);
            if (w) r.wallet_name = w.name;
          });
        }
      }
      const whereClause = selectMatch[4];
      if (whereClause) {
        if (table === 'wallets') {
          if (whereClause.includes('company_id = ?') && whereClause.includes('scope = "company"') && whereClause.includes('user_id = ?')) {
            const cmpId = params[0];
            const usrId = params[1];
            return rows.filter(r => (String(r.company_id) === String(cmpId) && r.scope === 'company') || String(r.user_id) === String(usrId));
          }
          if (whereClause.includes('company_id = ?') && whereClause.includes('scope = "company"')) {
            const cmpId = params[0];
            return rows.filter(r => String(r.company_id) === String(cmpId) && r.scope === 'company');
          }
          if (whereClause.includes('family_id = ?') && whereClause.includes('scope = "family"') && whereClause.includes('user_id = ?')) {
            const famId = params[0];
            const usrId = params[1];
            return rows.filter(r => (String(r.family_id) === String(famId) && r.scope === 'family') || String(r.user_id) === String(usrId));
          }
        }
        if (table === 'transactions') {
          if ((whereClause.includes('t.company_id = ?') || whereClause.includes('company_id = ?')) && (whereClause.includes('t.user_id = ?') || whereClause.includes('user_id = ?'))) {
            const cmpId = params[0];
            const usrId = params[1];
            return rows.filter(r => (String(r.company_id) === String(cmpId) && r.scope === 'company') || String(r.user_id) === String(usrId));
          }
        }
        if (table === 'debts') {
          if (whereClause.includes('family_id = ?') && whereClause.includes('scope = "family"')) {
            const famId = params[0];
            const usrId = params[1];
            return rows.filter(r => (String(r.family_id) === String(famId) && r.scope === 'family') || (String(r.user_id) === String(usrId) && r.scope === 'family'));
          }
          if (whereClause.includes('company_id = ?') && whereClause.includes('scope = "company"')) {
            const cmpId = params[0];
            const usrId = params[1];
            return rows.filter(r => (String(r.company_id) === String(cmpId) && r.scope === 'company') || (String(r.user_id) === String(usrId) && r.scope === 'company'));
          }
          if (whereClause.includes('status != "paid"')) {
            rows = rows.filter(r => r.status !== 'paid' && Number(r.remaining_amount) > 0);
          }
        }

        let paramIdx = 0;
        const conditions = whereClause.split(/\s+AND\s+/i);
        for (const cond of conditions) {
          const gteMatch = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s*>=\s*\?/);
          if (gteMatch) {
            const col = gteMatch[1];
            const val = params[paramIdx++];
            rows = rows.filter(r => Number(r[col]) >= Number(val));
            continue;
          }
          const gtMatch = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s*>\s*\?/);
          if (gtMatch) {
            const col = gtMatch[1];
            const val = params[paramIdx++];
            rows = rows.filter(r => Number(r[col]) > Number(val));
            continue;
          }
          const neqMatch = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s*(?:!=|<>)\s*\?/);
          if (neqMatch) {
            const col = neqMatch[1];
            const val = params[paramIdx++];
            rows = rows.filter(r => String(r[col]) !== String(val));
            continue;
          }
          const eqMatch = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s*=\s*\?/);
          if (eqMatch) {
            const col = eqMatch[1];
            const val = params[paramIdx++];
            rows = rows.filter(r => String(r[col]) === String(val));
            continue;
          }
          const nullMatch = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s+IS\s+NULL/i);
          if (nullMatch) {
            const col = nullMatch[1];
            rows = rows.filter(r => r[col] === null || r[col] === undefined);
            continue;
          }
        }
      }

      if (selectMatch[5]) {
        const orderClause = selectMatch[5].trim();
        const desc = /DESC/i.test(orderClause);
        const colMatch = orderClause.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)/);
        if (colMatch) {
          const col = colMatch[1];
          rows.sort((a, b) => {
            if (a[col] < b[col]) return desc ? 1 : -1;
            if (a[col] > b[col]) return desc ? -1 : 1;
            return 0;
          });
        }
      }
      if (selectMatch[6]) {
        const limit = Number(selectMatch[6]);
        rows = rows.slice(0, limit);
      }
      return rows;
    }

    const updateMatch = cleanSql.match(/^UPDATE\s+([a-zA-Z0-9_]+)\s+SET\s+(.+?)\s+WHERE\s+(.+)$/is);
    if (updateMatch) {
      const table = updateMatch[1].toLowerCase();
      const whereClause = updateMatch[3].trim();
      const rows = this.tables[table] || [];
      const setParts = updateMatch[2].split(',').map(s => s.trim());
      const setParamCount = setParts.filter(p => p.includes('?')).length;
      const setVals = params.slice(0, setParamCount);
      const whereVals = params.slice(setParamCount);
      
      const whereConditions = whereClause.split(/\s+AND\s+/i);
      let affected = 0;
      rows.forEach(row => {
        let match = true;
        let wIdx = 0;
        for (const cond of whereConditions) {
          const m = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s*=\s*\?/i);
          if (m) {
            const col = m[1].toLowerCase();
            const val = whereVals[wIdx++];
            if (String(row[col]) !== String(val)) {
              match = false;
              break;
            }
          }
        }
        if (match) {
          let sIdx = 0;
          setParts.forEach(part => {
            const col = part.split('=')[0].trim().replace(/[`"']/g, '');
            if (part.includes('?')) {
              row[col] = setVals[sIdx++];
            } else if (/NOW\(\)|CURRENT_TIMESTAMP/i.test(part)) {
              row[col] = new Date().toISOString();
            }
          });
          affected++;
        }
      });
      return { affectedRows: affected };
    }

    const deleteMatch = cleanSql.match(/^DELETE\s+FROM\s+([a-zA-Z0-9_]+)\s+WHERE\s+([a-zA-Z0-9_]+)\s*=\s*\?/i);
    if (deleteMatch) {
      const table = deleteMatch[1].toLowerCase();
      const col = deleteMatch[2].toLowerCase();
      const val = params[0];
      const initialLen = (this.tables[table] || []).length;
      this.tables[table] = (this.tables[table] || []).filter(r => String(r[col]) !== String(val));
      return { affectedRows: initialLen - this.tables[table].length };
    }

    return [];
  }

  async transaction(callback) {
    const backupTables = JSON.parse(JSON.stringify(this.tables));
    const backupAuto = { ...this.autoIncrement };
    try {
      const result = await callback(this);
      return result;
    } catch (err) {
      this.tables = backupTables;
      this.autoIncrement = backupAuto;
      throw err;
    }
  }
}

const mockDbInstance = new MockDatabase();

export const db = {
  mock: mockDbInstance,
  hasTable(tableName) {
    return mockDbInstance.hasTable(tableName);
  },
  async query(sql, params = []) {
    if (isRunningTest) {
      try {
        const p = await getPool();
        const [results] = await p.query(sql, params);
        return results;
      } catch {
        return mockDbInstance.query(sql, params);
      }
    }
    const p = await getPool();
    const [results] = await p.query(sql, params);
    return results;
  },

  async transaction(callback) {
    if (isRunningTest) {
      try {
        const p = await getPool();
        const connection = await p.getConnection();
        await connection.beginTransaction();
        try {
          const trx = {
            query: async (s, prms = []) => {
              const [res] = await connection.query(s, prms);
              return res;
            }
          };
          const result = await callback(trx);
          await connection.commit();
          return result;
        } catch (err) {
          await connection.rollback();
          throw err;
        } finally {
          connection.release();
        }
      } catch {
        return mockDbInstance.transaction(callback);
      }
    }

    const p = await getPool();
    const connection = await p.getConnection();
    await connection.beginTransaction();
    try {
      const trx = {
        query: async (s, prms = []) => {
          const [res] = await connection.query(s, prms);
          return res;
        }
      };
      const result = await callback(trx);
      await connection.commit();
      return result;
    } catch (err) {
      await connection.rollback();
      throw err;
    } finally {
      connection.release();
    }
  }
};
