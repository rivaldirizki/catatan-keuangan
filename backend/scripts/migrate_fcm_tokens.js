import mysql from 'mysql2/promise';

async function migrate() {
  const conn = await mysql.createConnection({
    host: '127.0.0.1',
    user: 'root',
    password: '',
    database: 'finance_db'
  });

  await conn.query(`
    CREATE TABLE IF NOT EXISTS user_device_tokens (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      fcm_token VARCHAR(500) NOT NULL,
      platform VARCHAR(20) DEFAULT 'android',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY unique_fcm_token (fcm_token),
      INDEX idx_user_tokens (user_id)
    );
  `);

  console.log('user_device_tokens table ready');
  await conn.end();
}

migrate().catch(console.error);
