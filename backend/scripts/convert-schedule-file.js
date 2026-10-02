import fs from 'node:fs/promises';
import path from 'node:path';

import { parseScheduleFile } from '../src/utils/schedule-import.js';

const inputPath = process.argv[2];
const outputPath = process.argv[3] ?? 'rmutt_class_schedules.csv';

if (!inputPath) {
  console.error(
    'Usage: npm run schedules:convert -- "timetable.xlsx" "output.csv"',
  );
  process.exitCode = 1;
} else {
  try {
    const buffer = await fs.readFile(inputPath);
    const result = await parseScheduleFile({
      buffer,
      fileName: path.basename(inputPath),
    });
    await fs.writeFile(outputPath, result.csv, 'utf8');

    console.log(`Semester: ${result.semester || '-'}`);
    console.log(`Rooms: ${result.roomNumbers.length}`);
    console.log(`Schedules: ${result.schedules.length}`);
    for (const warning of result.warnings) {
      console.warn(`Warning: ${warning}`);
    }
    console.log(`CSV: ${path.resolve(outputPath)}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
