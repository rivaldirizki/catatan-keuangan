import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// In-memory relational store for testing or sandboxed environments
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

    // Handle INSERT INTO <table> (...) VALUES (...)
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

    // Handle SELECT FROM <table>
    const selectMatch = cleanSql.match(/^SELECT\s+(.+?)\s+FROM\s+([a-zA-Z0-9_]+)(?:\s+WHERE\s+(.+?))?(?:\s+ORDER\s+BY\s+(.+?))?(?:\s+LIMIT\s+(\d+))?$/is);
    if (selectMatch) {
      const table = selectMatch[2].toLowerCase();
      let rows = [...(this.tables[table] || [])];
      
      const whereClause = selectMatch[3];
      if (whereClause) {
        let paramIdx = 0;
        const conditions = whereClause.split(/\s+AND\s+/i);
        for (const cond of conditions) {
          const eqMatch = cond.match(/([a-zA-Z0-9_]+)\s*=\s*\?/);
          if (eqMatch) {
            const col = eqMatch[1];
            const val = params[paramIdx++];
            rows = rows.filter(r => String(r[col]) === String(val));
          }
          const nullMatch = cond.match(/([a-zA-Z0-9_]+)\s+IS\s+NULL/i);
          if (nullMatch) {
            const col = nullMatch[1];
            rows = rows.filter(r => r[col] === null || r[col] === undefined);
          }
        }
      }

      return rows;
    }

    // Handle UPDATE <table> SET ... WHERE id = ?
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

    // Handle DELETE FROM <table> WHERE id = ?
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
    // Snapshot state for rollback
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

// MySQL real client loader
let realPool = null;

async function getMysqlPool() {
  if (realPool) return realPool;
  try {
    const mysql = await import('mysql2/promise');
    realPool = mysql.createPool({
      host: process.env.DB_HOST || 'localhost',
      port: Number(process.env.DB_PORT) || 3306,
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'finance_db',
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });
    return realPool;
  } catch (e) {
    return null;
  }
}

const mockDbInstance = new MockDatabase();

export const db = {
  isMock: process.env.NODE_ENV === 'test' || !process.env.DB_USE_REAL,
  mock: mockDbInstance,
  hasTable(tableName) {
    return mockDbInstance.hasTable(tableName);
  },
  async query(sql, params = []) {
    if (this.isMock) {
      return mockDbInstance.query(sql, params);
    }
    const pool = await getMysqlPool();
    if (!pool) {
      return mockDbInstance.query(sql, params);
    }
    try {
      const [rows] = await pool.query(sql, params);
      return rows;
    } catch (err) {
      if (process.env.NODE_ENV === 'test') {
        return mockDbInstance.query(sql, params);
      }
      throw err;
    }
  },
  async transaction(callback) {
    if (this.isMock) {
      return mockDbInstance.transaction(callback);
    }
    const pool = await getMysqlPool();
    if (!pool) {
      return mockDbInstance.transaction(callback);
    }
    const connection = await pool.getConnection();
    await connection.beginTransaction();
    try {
      const trxWrapper = {
        query: async (sql, params) => {
          const [rows] = await connection.query(sql, params);
          return rows;
        }
      };
      const result = await callback(trxWrapper);
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
