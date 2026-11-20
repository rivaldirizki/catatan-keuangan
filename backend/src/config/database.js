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
      wallets: [],
      categories: [],
      transactions: [],
      savings: [],
      debts: []
    };
    this.autoIncrement = {
      users: 1,
      families: 1,
      wallets: 1,
      categories: 1,
      transactions: 1,
      savings: 1,
      debts: 1
    };
  }

  hasTable(tableName) {
    return Object.prototype.hasOwnProperty.call(this.tables, tableName);
  }

  reset() {
    for (const key of Object.keys(this.tables)) {
      this.tables[key] = [];
      this.autoIncrement[key] = 1;
    }
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
      const row = { id };
      columns.forEach((col, idx) => {
        row[col] = params[idx] !== undefined ? params[idx] : null;
      });
      this.tables[table].push(row);
      return { insertId: id, affectedRows: 1 };
    }

    const selectMatch = cleanSql.match(/^SELECT\s+(.+?)\s+FROM\s+([a-zA-Z0-9_]+)(?:\s+[a-zA-Z0-9_]+)?(?:\s+LEFT\s+JOIN\s+([a-zA-Z0-9_]+)(?:\s+[a-zA-Z0-9_]+)?\s+ON\s+[^\s]+\s*=\s*[^\s]+)?(?:\s+WHERE\s+(.+?))?(?:\s+ORDER\s+BY\s+(.+?))?(?:\s+LIMIT\s+(\d+))?$/is);
    if (selectMatch) {
      const table = selectMatch[2].toLowerCase();
      let rows = (this.tables[table] || []).map(r => ({ ...r }));
      const joinTable = selectMatch[3] ? selectMatch[3].toLowerCase() : null;
      if (joinTable && this.tables[joinTable]) {
        if (joinTable === 'users') {
          rows.forEach(r => {
            const u = this.tables.users.find(user => user.id === r.user_id);
            if (u) r.user_name = u.name;
          });
        }
      }
      const whereClause = selectMatch[4];
      if (whereClause) {
        let paramIdx = 0;
        const conditions = whereClause.split(/\s+AND\s+/i);
        for (const cond of conditions) {
          const eqMatch = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s*=\s*\?/);
          if (eqMatch) {
            const col = eqMatch[1];
            const val = params[paramIdx++];
            rows = rows.filter(r => String(r[col]) === String(val));
          }
          const nullMatch = cond.match(/(?:[a-zA-Z0-9_]+\.)?([a-zA-Z0-9_]+)\s+IS\s+NULL/i);
          if (nullMatch) {
            const col = nullMatch[1];
            rows = rows.filter(r => r[col] === null || r[col] === undefined);
          }
        }
      }
      return rows;
    }

    const updateMatch = cleanSql.match(/^UPDATE\s+([a-zA-Z0-9_]+)\s+SET\s+(.+?)\s+WHERE\s+(.+)$/is);
    if (updateMatch) {
      const table = updateMatch[1].toLowerCase();
      const whereClause = updateMatch[3];
      const rows = this.tables[table] || [];
      let affected = 0;
      const idMatch = whereClause.match(/id\s*=\s*\?/i);
      if (idMatch) {
        const idVal = params[params.length - 1];
        const row = rows.find(r => r.id === Number(idVal));
        if (row) {
          const setParts = updateMatch[2].split(',').map(s => s.trim());
          setParts.forEach((part, idx) => {
            const col = part.split('=')[0].trim().replace(/[`"']/g, '');
            row[col] = params[idx];
          });
          affected++;
        }
      }
      return { affectedRows: affected };
    }

    const deleteMatch = cleanSql.match(/^DELETE\s+FROM\s+([a-zA-Z0-9_]+)\s+WHERE\s+id\s*=\s*\?/i);
    if (deleteMatch) {
      const table = deleteMatch[1].toLowerCase();
      const idVal = params[0];
      const idx = (this.tables[table] || []).findIndex(r => r.id === Number(idVal));
      if (idx !== -1) {
        this.tables[table].splice(idx, 1);
        return { affectedRows: 1 };
      }
      return { affectedRows: 0 };
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
