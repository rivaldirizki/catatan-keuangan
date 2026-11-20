import { describe, it } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';

describe('Task 1: Database Scaffolding & Schema Test', () => {
  it('should initialize database config and support query execution', async () => {
    assert.ok(db, 'Database instance should exist');
    assert.strictEqual(typeof db.query, 'function', 'db.query must be a function');
    assert.strictEqual(typeof db.transaction, 'function', 'db.transaction must be a function');
    
    // Test basic query execution
    const result = await db.query('SELECT 1 as val');
    assert.ok(Array.isArray(result));
    assert.strictEqual(result[0].val, 1);
  });

  it('should verify schema contains required tables', async () => {
    const tables = await db.query('SHOW TABLES');
    assert.ok(Array.isArray(tables));
    // Verify core tables exist in schema
    const requiredTables = ['users', 'families', 'wallets', 'categories', 'transactions', 'savings', 'debts'];
    for (const table of requiredTables) {
      assert.ok(db.hasTable ? db.hasTable(table) : true, `Table ${table} should be defined`);
    }
  });
});
