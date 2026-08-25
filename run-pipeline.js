// .hermes/run-pipeline.js — Zero-Dependency Pre-Completion Pipeline Runner
//
// Two modes:
//   node .hermes/run-pipeline.js                                              -> RUN: execute steps, write artifact
//   node .hermes/run-pipeline.js --check <artifact.json>                     -> CHECK: validate an existing artifact
//
// Produces docs/superpowers/pre-completion-<date>.json with per-step evidence.
// Fail-aggregate: reports ALL failing steps before exiting non-zero.

const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');

function localDate() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

const today = localDate();
const ARTIFACT = path.join('docs', 'superpowers', `pre-completion-${today}.json`);

// Locked step list — deterministic, no arbitrary command execution.
const STEPS = [
  { name: 'gate',        command: 'bash .hermes/pre-code-gate.sh .' },
  { name: 'build',       command: 'pnpm run build' },
  { name: 'tests',       command: 'pnpm run test' },
  { name: 'impact-audit', command: `test -f docs/superpowers/specs/${today}-impact-audit.md` },
  { name: 'docs-audit',  command: `grep -q -e VERIFIED -e SHIPPED -e DEFERRED docs/superpowers/specs/${today}-impact-audit.md` },
];
const STEP_NAMES = STEPS.map(s => s.name);

function runStep(command) {
  const start = Date.now();
  try {
    const stdout = execSync(command, { timeout: 300000, encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
    return {
      status: 'PASS',
      exit_code: 0,
      duration_ms: Date.now() - start,
      evidence: String(stdout || '').trim().slice(-1500),
    };
  } catch (err) {
    const out = (err.stdout || '').toString().trim();
    const errOut = (err.stderr || '').toString().trim();
    return {
      status: 'FAIL',
      exit_code: typeof err.status === 'number' ? err.status : 1,
      duration_ms: Date.now() - start,
      evidence: (out || errOut || err.message).slice(-1500),
    };
  }
}

// ── CHECK MODE ──────────────────────────────────────────────────
if (process.argv[2] === '--check') {
  const file = process.argv[3] || ARTIFACT;
  if (!fs.existsSync(file)) {
    console.error(`WARN: no pre-completion artifact at ${file}`);
    process.exit(1);
  }
  let artifact;
  try {
    artifact = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (err) {
    console.error(`WARN: invalid JSON in ${file}: ${err.message}`);
    process.exit(1);
  }
  const violations = [];
  const steps = artifact.steps || {};
  // Omission check
  for (const name of STEP_NAMES) {
    if (!Object.hasOwn(steps, name)) violations.push(`missing step: ${name}`);
  }
  // Pollution check
  for (const name of Object.keys(steps)) {
    if (!STEP_NAMES.includes(name)) violations.push(`unknown step: ${name}`);
  }
  // Status check
  for (const name of STEP_NAMES) {
    const s = steps[name];
    if (!s || typeof s !== 'object') continue;
    if (s.status !== 'PASS') violations.push(`step ${name}: status ${s.status}`);
    if (typeof s.exit_code !== 'number') violations.push(`step ${name}: no exit_code`);
  }
  if (violations.length > 0) {
    console.error(`WARN: pre-completion artifact invalid (${violations.length}):`);
    console.error(violations.map(v => `  - ${v}`).join('\n'));
    process.exit(1);
  }
  console.log('PASS: pre-completion artifact valid.');
  process.exit(0);
}

// ── RUN MODE ───────────────────────────────────────────────────
const results = {};
const violations = [];
for (const step of STEPS) {
  process.stderr.write(`[${step.name}] ... `);
  const r = runStep(step.command);
  results[step.name] = { command: step.command, ...r };
  process.stderr.write(`${r.status} (${r.duration_ms}ms)\n`);
  if (r.status !== 'PASS') violations.push(`step ${step.name}: ${r.status} (exit ${r.exit_code})`);
}

const artifact = {
  agent: 'deepseek-v4-pro',
  completed_at: new Date().toISOString(),
  commit: (() => { try { return execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim(); } catch { return 'unknown'; } })(),
  steps: results,
};

fs.writeFileSync(ARTIFACT, JSON.stringify(artifact, null, 2) + '\n');

if (violations.length > 0) {
  console.error(`\nPIPELINE FAILED (${violations.length} step(s) failed):`);
  console.error(violations.map(v => `  - ${v}`).join('\n'));
  process.exit(1);
}

console.log(`\nSUCCESS: pre-completion pipeline passed (${STEP_NAMES.length}/${STEP_NAMES.length} steps).`);
console.log(`Artifact written to ${ARTIFACT}`);
process.exit(0);
