// .hermes/validate-audit.js — Zero-Dependency, Fail-Aggregate Production-Readiness Validator
const fs = require('node:fs');
const path = require('node:path');

const filePath = process.argv[2] || path.join('docs', 'superpowers', 'production-readiness.json');

let content;
try {
  content = fs.readFileSync(filePath, 'utf8');
} catch (err) {
  console.error(`FATAL: Cannot read audit file '${filePath}': ${err.message}`);
  process.exit(1);
}

let artifact;
try {
  artifact = JSON.parse(content);
} catch (err) {
  console.error(`FATAL: Invalid JSON in audit file: ${err.message}`);
  process.exit(1);
}

const EXPECTED_DIMENSIONS = [
  'rls_policies',
  'webhook_idempotency',
  'secrets_management',
];

const violations = [];
const dimensions = artifact.dimensions || {};
const presentKeys = Object.keys(dimensions);

// 1. Missing dimensions (omission)
for (const expected of EXPECTED_DIMENSIONS) {
  if (!Object.hasOwn(dimensions, expected)) {
    violations.push(`Missing required dimension: '${expected}'`);
  }
}

// 2. Unknown dimensions (pollution / misspelling)
for (const present of presentKeys) {
  if (!EXPECTED_DIMENSIONS.includes(present)) {
    violations.push(`Unknown or unexpected dimension: '${present}'`);
  }
}

// 3. Status + evidence validation
for (const [dim, v] of Object.entries(dimensions)) {
  if (!v || typeof v !== 'object') {
    violations.push(`${dim}: invalid dimension object schema`);
    continue;
  }
  if (!['PASS', 'FAIL', 'WARN'].includes(v.status)) {
    violations.push(`${dim}: invalid status '${v.status}' (must be PASS, FAIL, or WARN)`);
  }
  if (typeof v.evidence !== 'string' || !v.evidence.trim()) {
    violations.push(`${dim}: missing or empty evidence string`);
  }
}

if (violations.length > 0) {
  console.error(`AUDIT VALIDATION FAILED (${violations.length} violations):`);
  console.error(violations.map(v => `  - ${v}`).join('\n'));
  process.exit(1);
}

console.log('SUCCESS: Production readiness audit mechanical verification passed.');
process.exit(0);
