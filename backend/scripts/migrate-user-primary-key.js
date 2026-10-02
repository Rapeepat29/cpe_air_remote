import { config } from '../src/config.js';
import { pool } from '../src/db.js';

const database = config.db.database;

try {
  if (!(await tableExists('users'))) {
    throw new Error('Table "users" does not exist. Run "npm run db:init" first.');
  }

  const userColumns = await columnNames('users');
  if (!userColumns.has('username')) {
    throw new Error('Table "users" does not contain a username column.');
  }

  const hasOtpTable = await tableExists('password_reset_otps');
  if (hasOtpTable) {
    await prepareOtpUsernames();
  }

  await normalizeRoles();
  await makeUsernamePrimaryKey();

  if (hasOtpTable) {
    await finishOtpUsernameReference();
  }

  await verifyFinalStructure(hasOtpTable);

  console.log(
    'Username migration complete: users.username is the primary key.',
  );
} finally {
  await pool.end();
}

async function prepareOtpUsernames() {
  const columns = await columnNames('password_reset_otps');

  if (!columns.has('username')) {
    await pool.query(
      `ALTER TABLE password_reset_otps
         ADD COLUMN username VARCHAR(100) NULL AFTER id`,
    );
    columns.add('username');
  }

  if (columns.has('user_id') && (await columnNames('users')).has('id')) {
    await pool.query(
      `UPDATE password_reset_otps AS otp
         JOIN users AS user_account ON user_account.id = otp.user_id
          SET otp.username = user_account.username
        WHERE otp.username IS NULL OR otp.username = ''`,
    );
  }

  const missingRows = await pool.query(
    `SELECT COUNT(*) AS total
       FROM password_reset_otps
      WHERE username IS NULL OR username = ''`,
  );
  if (Number(missingRows[0].total) > 0) {
    throw new Error(
      'Some OTP rows cannot be matched to a username. Check the old user_id values before trying again.',
    );
  }

  if (columns.has('user_id')) {
    const foreignKeys = await pool.query(
      `SELECT DISTINCT constraint_name
         FROM information_schema.key_column_usage
        WHERE table_schema = ?
          AND table_name = 'password_reset_otps'
          AND column_name = 'user_id'
          AND referenced_table_name IS NOT NULL`,
      [database],
    );
    for (const foreignKey of foreignKeys) {
      await pool.query(
        `ALTER TABLE password_reset_otps DROP FOREIGN KEY ${quoteIdentifier(
          foreignKey.constraint_name,
        )}`,
      );
    }

    const indexes = await pool.query(
      `SELECT DISTINCT index_name
         FROM information_schema.statistics
        WHERE table_schema = ?
          AND table_name = 'password_reset_otps'
          AND column_name = 'user_id'
          AND index_name <> 'PRIMARY'`,
      [database],
    );
    for (const index of indexes) {
      await pool.query(
        `ALTER TABLE password_reset_otps DROP INDEX ${quoteIdentifier(
          index.index_name,
        )}`,
      );
    }

    await pool.query(
      'ALTER TABLE password_reset_otps DROP COLUMN user_id',
    );
  }
}

async function normalizeRoles() {
  await pool.query(
    `ALTER TABLE users
       MODIFY COLUMN role VARCHAR(30) NULL`,
  );
  await pool.query(
    `UPDATE users
        SET role = 'staff'
      WHERE role IS NULL
         OR LOWER(TRIM(role)) NOT IN ('admin', 'staff')`,
  );
  await pool.query(
    `UPDATE users
        SET role = LOWER(TRIM(role))`,
  );
  await pool.query(
    `ALTER TABLE users
       MODIFY COLUMN role ENUM('admin', 'staff') NOT NULL DEFAULT 'staff'`,
  );
}

async function makeUsernamePrimaryKey() {
  const columns = await columnNames('users');
  const primaryColumns = await primaryKeyColumns('users');

  if (columns.has('id')) {
    await pool.query(
      'ALTER TABLE users MODIFY COLUMN id BIGINT UNSIGNED NOT NULL',
    );
  }

  if (primaryColumns.length > 0 && primaryColumns[0] !== 'username') {
    await pool.query('ALTER TABLE users DROP PRIMARY KEY');
  }

  if (!(await primaryKeyColumns('users')).includes('username')) {
    await pool.query('ALTER TABLE users ADD PRIMARY KEY (username)');
  }

  if (columns.has('id')) {
    await pool.query('ALTER TABLE users DROP COLUMN id');
  }

  const usernameUniqueIndexes = await pool.query(
    `SELECT index_name
       FROM information_schema.statistics
      WHERE table_schema = ?
        AND table_name = 'users'
        AND column_name = 'username'
        AND non_unique = 0
        AND index_name <> 'PRIMARY'
      GROUP BY index_name`,
    [database],
  );
  for (const index of usernameUniqueIndexes) {
    await pool.query(
      `ALTER TABLE users DROP INDEX ${quoteIdentifier(index.index_name)}`,
    );
  }
}

async function finishOtpUsernameReference() {
  await pool.query(
    `ALTER TABLE password_reset_otps
       MODIFY COLUMN username VARCHAR(100) NOT NULL`,
  );

  const usernameIndexes = await pool.query(
    `SELECT DISTINCT index_name
       FROM information_schema.statistics
      WHERE table_schema = ?
        AND table_name = 'password_reset_otps'
        AND column_name = 'username'
        AND seq_in_index = 1`,
    [database],
  );
  if (usernameIndexes.length === 0) {
    await pool.query(
      `ALTER TABLE password_reset_otps
         ADD INDEX idx_password_reset_username (username, created_at)`,
    );
  }

  const usernameForeignKeys = await pool.query(
    `SELECT constraint_name
       FROM information_schema.key_column_usage
      WHERE table_schema = ?
        AND table_name = 'password_reset_otps'
        AND column_name = 'username'
        AND referenced_table_name = 'users'
        AND referenced_column_name = 'username'`,
    [database],
  );
  if (usernameForeignKeys.length === 0) {
    await pool.query(
      `ALTER TABLE password_reset_otps
         ADD CONSTRAINT fk_password_reset_username
         FOREIGN KEY (username) REFERENCES users (username)
         ON DELETE CASCADE`,
    );
  }
}

async function verifyFinalStructure(hasOtpTable) {
  const userColumns = await columnNames('users');
  const userPrimaryKey = await primaryKeyColumns('users');
  if (
    userColumns.has('id') ||
    userPrimaryKey.length !== 1 ||
    userPrimaryKey[0] !== 'username'
  ) {
    throw new Error(
      'Migration verification failed: users.username is not the only primary key.',
    );
  }

  if (!hasOtpTable) return;

  const otpColumns = await columnNames('password_reset_otps');
  if (!otpColumns.has('username') || otpColumns.has('user_id')) {
    throw new Error(
      'Migration verification failed: the OTP table still uses user_id.',
    );
  }
}

async function tableExists(tableName) {
  const rows = await pool.query(
    `SELECT COUNT(*) AS total
       FROM information_schema.tables
      WHERE table_schema = ? AND table_name = ?`,
    [database, tableName],
  );
  return Number(rows[0].total) === 1;
}

async function columnNames(tableName) {
  const rows = await pool.query(
    `SELECT column_name
       FROM information_schema.columns
      WHERE table_schema = ? AND table_name = ?`,
    [database, tableName],
  );
  return new Set(rows.map((row) => row.column_name));
}

async function primaryKeyColumns(tableName) {
  const rows = await pool.query(
    `SELECT column_name
       FROM information_schema.key_column_usage
      WHERE table_schema = ?
        AND table_name = ?
        AND constraint_name = 'PRIMARY'
      ORDER BY ordinal_position`,
    [database, tableName],
  );
  return rows.map((row) => row.column_name);
}

function quoteIdentifier(identifier) {
  return `\`${String(identifier).replaceAll('`', '``')}\``;
}
