import { parse } from 'csv-parse/sync';

export function parseCsvBuffer(buffer) {
  const content = buffer.toString('utf-8');
  let records;
  try {
    records = parse(content, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
    });
  } catch {
    return { rows: [], errors: ['Failed to parse CSV. Check file format.'] };
  }

  if (records.length === 0) {
    return { rows: [], errors: ['CSV file is empty'] };
  }

  const rows = [];
  const errors = [];

  for (let i = 0; i < records.length; i++) {
    const row = records[i];
    const username = row.username?.trim();
    const label = row.label?.trim();
    const lineNum = i + 2;

    const rowErrors = [];
    if (!username) rowErrors.push('username is required');
    if (!label) rowErrors.push('label is required');

    if (rowErrors.length > 0) {
      errors.push({ line: lineNum, errors: rowErrors });
    } else {
      rows.push({ username, label });
    }
  }

  return { rows, errors };
}

// Parse CSV for per-user upload: columns = label, latitude, longitude
export function parseCsvRowsForUser(buffer) {
  const content = buffer.toString('utf-8');
  let records;
  try {
    records = parse(content, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
    });
  } catch {
    return { rows: [], errors: ['Failed to parse CSV. Check file format.'] };
  }

  if (records.length === 0) {
    return { rows: [], errors: ['CSV file is empty'] };
  }

  const rows = [];
  const errors = [];

  for (let i = 0; i < records.length; i++) {
    const row = records[i];
    const label = row.label?.trim();
    const latitude = parseFloat(row.latitude);
    const longitude = parseFloat(row.longitude);
    const lineNum = i + 2;

    const rowErrors = [];
    if (!label) rowErrors.push('label is required');
    if (isNaN(latitude)) rowErrors.push('latitude must be a number');
    else if (latitude < -90 || latitude > 90) rowErrors.push('latitude must be between -90 and 90');
    if (isNaN(longitude)) rowErrors.push('longitude must be a number');
    else if (longitude < -180 || longitude > 180) rowErrors.push('longitude must be between -180 and 180');

    if (rowErrors.length > 0) {
      errors.push({ line: lineNum, errors: rowErrors });
    } else {
      rows.push({ label, latitude, longitude });
    }
  }

  return { rows, errors };
}
