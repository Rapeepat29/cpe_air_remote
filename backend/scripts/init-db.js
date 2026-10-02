import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import mariadb from 'mariadb';

import { config } from '../src/config.js';

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const schemaPath = path.join(currentDirectory, '..', 'database', 'schema.sql');
const schema = await fs.readFile(schemaPath, 'utf8');

let connection;
try {
  const {
    connectionLimit: ignoredConnectionLimit,
    ...connectionConfig
  } = config.db;
  void ignoredConnectionLimit;
  connection = await mariadb.createConnection({
    ...connectionConfig,
    multipleStatements: true,
  });
  await connection.query(schema);
  console.log(`Database schema initialized in "${config.db.database}".`);
} finally {
  if (connection) {
    await connection.end();
  }
}
