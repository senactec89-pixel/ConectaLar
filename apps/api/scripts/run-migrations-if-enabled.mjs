import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

if (process.env.RUN_MIGRATIONS_ON_BUILD !== 'true') {
  console.info('Database migrations skipped.');
  process.exit(0);
}

const dataSource = resolve('dist/database/data-source.js');
if (!existsSync(dataSource)) {
  console.error('Database migrations could not run because the compiled data source is missing.');
  process.exit(1);
}

console.info('Running pending database migrations.');
const result = spawnSync(
  process.execPath,
  ['node_modules/typeorm/cli.js', 'migration:run', '-d', dataSource],
  { stdio: 'inherit', env: process.env },
);

if (result.error) {
  console.error('Database migrations could not be started.');
  process.exit(1);
}

process.exit(result.status ?? 1);
