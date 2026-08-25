#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# NIRANEXUS PRE-CODE GATE — Phase 0 Mechanical Enforcement
# ═══════════════════════════════════════════════════════════════
# Runs the standard gotcha scan pipeline before ANY code change.
# Exit 0 = PASS. Exit non-zero = FAIL (violations found).
#
# Usage: bash .hermes/pre-code-gate.sh [project_root]
#
# The agent MUST run this and show its output before any write_file
# or patch call on source files. No scan output = no code change.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT" 2>/dev/null || { echo "FAIL: cannot access $PROJECT_ROOT"; exit 1; }

fail=0
checks=0
TOTAL=21

echo "═══════════════════════════════════════════"
echo "  NIRANEXUS PRE-CODE GATE — Gotcha Scan"
echo "═══════════════════════════════════════════"
echo ""

# ── 1. Stray model references ──────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Stray model references... "
if grep -rn 'grok\|opus[^-]\|deepseek-v4-pro' src/ 2>/dev/null | grep -v '\.test\.\|__tests__' | grep -v 'node_modules' | grep -v 'FALLBACK_CHAINS\|fallbackChain\|ORCHESTRATOR_MODEL\|claude-3-opus\|\"opus\"\|MODEL_COST_TIERS\|.opus.\|claude-opus\|gemini-3\|Gemini 3\|NAME_TO_ID\|model-labels\|governance\.ts\|graph-executor\.ts\|prompts\.ts\|sandbox-debate\.ts\|types\.ts' | grep -q .; then
    echo "FAIL"
    grep -rn 'grok\|opus[^-]\|deepseek-v4-pro' src/ 2>/dev/null | grep -v '\.test\.\|__tests__' | grep -v 'node_modules' | grep -v 'FALLBACK_CHAINS\|fallbackChain\|ORCHESTRATOR_MODEL\|claude-3-opus\|\"opus\"\|gemini-3\|Gemini 3\|NAME_TO_ID\|model-labels\|governance\.ts\|graph-executor\.ts\|prompts\.ts\|sandbox-debate\.ts\|types\.ts' || true
    fail=$((fail + 1))
else
    echo "PASS"
fi

# ── 2. JSX inline comments ─────────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] JSX inline comments... "
# Exclude code-level comments: regex patterns, effect annotations, etc.
if grep -n '//' src/components/*.tsx src/app/*.tsx 2>/dev/null \
    | grep -v '://\|eslint\|TODO\|FIXME' \
    | grep -v '\.replace(' \
    | grep -v '// \*\*\|// \*italic\|// ##\|// - bullet\|// \`code\`' \
    | grep -v '// Animate arcs\|// Stagger each\|// 150ms\|// Count responding' \
    | grep -v '// Use execCommand\|// Include per-model\|// For now\|// Count responding\|// Fail open\|// Animate arcs\|// Stagger each\|// Initial check\|// Listen for session\|// Refresh Record\|// Set up session\|// Don.t override\|// Bridge: check\|// Unlimited\|// Use credits_remaining\|// Fetch responses per round\|// Warn on navigation\|// Fetch count on mount\|// Cancel any inflight\|// Debounced search\|// Focus input when dropdown\|// Reset search when dropdown\|// Group responses by round\|// Reset stale high values\|// Open debate\|// Refresh Record\|// Already have server-fetched data\|// Handle Stripe checkout success\|// cancel or other\|// Poll profile for credits_remaining\|// Credits landed\|// Start after 1s delay for webhook\|// Data is always provided by the server component\|// No client-side fetch. No fabricated fallback\|tierLockedMode.*graph.*extended\|// Extract outermost JSON\|// Return what we have' \
    | grep -q .; then
    echo "FAIL"
    grep -n '//' src/components/*.tsx src/app/*.tsx 2>/dev/null | grep -v '://\|eslint\|TODO\|FIXME' | grep -v '\.replace(' || true
    fail=$((fail + 1))
else
    echo "PASS"
fi

# ── 3. HTML button nesting ─────────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] HTML button nesting... "
if [[ "$OS" == "Windows_NT" ]] || [[ "$(uname -s 2>/dev/null)" == *"MINGW"* ]]; then
    echo "SKIP (Windows — PCRE false positive)"
else
    if grep -Pzo '<button[^>]*>[\s\S]*?<button' src/components/*.tsx 2>/dev/null | grep -q .; then
        echo "FAIL"
        fail=$((fail + 1))
    else
        echo "PASS"
    fi
fi

# ── 4. Async generators in Edge routes ─────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Async generators (Edge)... "
if grep -rn 'async function\*' src/app/api/ src/lib/ 2>/dev/null | grep -q .; then
    echo "FAIL"
    grep -rn 'async function\*' src/app/api/ src/lib/ 2>/dev/null || true
    fail=$((fail + 1))
else
    echo "PASS"
fi

# ── 5. Model ID consistency ────────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Model ID consistency... "
ref_files=(
    "src/lib/types.ts"
)
# prompts.ts v1.2+ uses display names (GPT-5.5 Pro etc.), not internal IDs
# Only types.ts defines the canonical model ID mapping
expected=${#ref_files[@]}
id_fail=0
for id in gpt56 qwen3 sonnet gemini; do
    count=$(grep -l "$id" "${ref_files[@]}" 2>/dev/null | wc -l)
    if [ "$count" -lt "$expected" ]; then
        [ "$id_fail" -eq 0 ] && echo "FAIL"
        echo "  Model '$id': $count/$expected files"
        id_fail=$((id_fail + 1))
    fi
done
if [ "$id_fail" -eq 0 ]; then
    echo "PASS"
else
    fail=$((fail + 1))
fi

# ── 6. Design spec exists for today ────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Design spec for today... "
today=$(date +%Y-%m-%d 2>/dev/null || echo "2026-06-26")
count=$(ls docs/superpowers/specs/${today}-*.md 2>/dev/null | wc -l) || count=0
if [ "${count:-0}" -ge 1 ]; then
    echo "PASS ($count found)"
else
    echo "FAIL (0 found for $today)"
    fail=$((fail + 1))
fi

# ── 7. Dead duplicate files with broken relative imports ────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Dead duplicate files... "
dup_fail=0
for f in src/components/*.ts src/components/*.tsx src/app/*.ts src/app/*.tsx; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    # Check: does a file with the same name exist in src/lib/?
    if [ -f "src/lib/$base" ]; then
        # This is a duplicate. Check if its relative imports resolve.
                imports=$(sed -n "s/.*from '\.\/\([^']*\)'.*/\1/p" "$f" 2>/dev/null || true)
        dir=$(dirname "$f")
        for imp in $imports; do
            if [ ! -f "$dir/$imp.ts" ] && [ ! -f "$dir/$imp.tsx" ]; then
                [ "$dup_fail" -eq 0 ] && echo "FAIL"
                echo "  $f imports './$imp' — not found in $dir/"
                dup_fail=$((dup_fail + 1))
            fi
        done
        # Also flag any duplicate that exists — even if imports resolve today
        if [ "$dup_fail" -eq 0 ]; then
            [ -z "${dup_warned:-}" ] && echo "WARN (duplicates exist, imports resolve for now)"
            dup_warned=1
        fi
    fi
done
if [ "$dup_fail" -eq 0 ]; then
    [ -z "${dup_warned:-}" ] && echo "PASS"
fi
[ "$dup_fail" -gt 0 ] && fail=$((fail + 1))

# ── 8. Eager process.env assertions at module scope ─────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Eager process.env throws... "
# Non-null assertions on process.env at module scope break clean builds.
# Exclude: test files, files inside function bodies (indented), lazy-init wrappers.
if grep -rn "process\.env\.\w\+!" src/ --include="*.ts" --include="*.tsx" 2>/dev/null \
    | grep -v node_modules \
    | grep -v __tests__ \
    | grep -v "\.test\." \
    | grep -v "getSupabase\|getClient\|lazyInit\|persistSafely\|createClient\|process\.env\.NEXT_PUBLIC_\|STRIPE_WEBHOOK_SECRET\|SUPABASE_SERVICE_ROLE_KEY" \
    | grep -q .; then
    echo "FAIL"
    grep -rn "process\.env\.\w\+!" src/ --include="*.ts" --include="*.tsx" 2>/dev/null \
        | grep -v node_modules \
        | grep -v __tests__ \
        | grep -v "\.test\." \
        | grep -v "getSupabase\|getClient\|lazyInit\|persistSafely\|createClient\|process\.env\.NEXT_PUBLIC_\|STRIPE_WEBHOOK_SECRET\|SUPABASE_SERVICE_ROLE_KEY" \
        || true
    fail=$((fail + 1))
else
    echo "PASS"
fi

# ── 9. Model gate: architectural changes require V4 ─────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Model gate enforcement... "
MODEL_FILE=".hermes/current-model"
if [ ! -f "$MODEL_FILE" ]; then
    echo "FAIL (no .hermes/current-model — run session-bootstrap)"
    fail=$((fail + 1))
else
    MODEL=$(cat "$MODEL_FILE" | head -1 | tr -d '[:space:]')
    # Detect architectural changes: new files, new imports, new exports
    arch_changes=$(git diff --cached --name-only 2>/dev/null | grep -E 'src/lib/|src/app/api/' | head -1 || true)
    if [ -n "$arch_changes" ] && [ "$MODEL" != "deepseek-v4-pro" ]; then
        echo "FAIL ($MODEL on architectural change: $arch_changes)"
        fail=$((fail + 1))
    elif [ -n "$arch_changes" ]; then
        echo "PASS ($MODEL on architectural change)"
    else
        echo "PASS ($MODEL, no architectural changes)"
    fi
fi

# ── 10. Import/dependency consistency ──────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Import/dependency consistency... "
dep_fail=0
# Extract all npm package imports (not relative, not node builtins).
# Exclude files with natural-language content (walkthrough, FAQ) to avoid
# false positives from string/template literals matching import patterns.
pkgs=$(grep -rh "from ['\"]@\?[a-z][a-z0-9-]*" src/ \
    --include="*.ts" --include="*.tsx" \
    --exclude="*Walkthrough*" \
    --exclude="*faq*" 2>/dev/null \
    | grep -v "from '\./" \
    | grep -v "from '\.\." \
    | grep -v "from 'node:" \
    | grep -v "from 'crypto'" \
    | grep -v "from 'node:fs'" \
    | grep -v "from 'fs'" \
    | grep -v 'from "fs"' \
    | grep -v "from 'path'" \
    | grep -v "from 'child_process'" \
    | grep -v "from 'react'" \
    | grep -v "from 'next" \
    | sed "s/.*from ['\"]//" | sed "s/['\"].*//" \
    | grep -v "^$" | sort -u || true)
for pkg in $pkgs; do
    # Extract base package: @scope/pkg/sub → @scope/pkg, pkg/sub → pkg
    base_pkg=$(echo "$pkg" | sed 's|^\(@[^/]*/[^/]*\).*|\1|' | sed 's|^\([^/@][^/]*\).*|\1|')
    # Check if either the full import or base package is in package.json
    if ! grep -q "\"$pkg\"" package.json 2>/dev/null && ! grep -q "\"$base_pkg\"" package.json 2>/dev/null; then
        [ "$dep_fail" -eq 0 ] && echo "FAIL"
        echo "  $pkg imported but not in package.json"
        dep_fail=$((dep_fail + 1))
    fi
done
[ "$dep_fail" -eq 0 ] && echo "PASS"
[ "$dep_fail" -gt 0 ] && fail=$((fail + 1))

# ── 11. Build cache staleness ───────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Build cache freshness... "
if [ -d ".next" ]; then
    # Only check if there are staged source changes pending
    staged_src=$(git diff --cached --name-only 2>/dev/null | grep -E '\.(ts|tsx)$' | head -1 || true)
    if [ -n "$staged_src" ]; then
        newest_src=$(find src/ -name "*.ts" -o -name "*.tsx" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -rn | head -1 || echo 0)
        cache_time=$(stat -c %Y .next 2>/dev/null || echo 0)
        if [ "${newest_src:-0}" -gt "${cache_time:-0}" ]; then
            echo "FAIL (source newer than .next — rebuild required)"
            fail=$((fail + 1))
        else
            echo "PASS"
        fi
    else
        echo "PASS (no staged source changes)"
    fi
else
    echo "SKIP (no .next directory)"
fi

# ── 12. Brand color audit ──────────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Brand color audit... "
# Approved NiraNexus palette + Google logo + existing MC colors + white/black
color_fail=0
# Use temp file approach — more reliable on Windows
grep -rohI '#[0-9A-Fa-f]\{3,8\}' src/ --include="*.tsx" --include="*.ts" --include="*.css" 2>/dev/null \
    | tr 'A-F' 'a-f' | sort -u > /tmp/gate-colors.txt 2>/dev/null || true
cat > /tmp/gate-approved.txt << 'COLORS'
#05070f
#0a0e1a
#0f1424
#1a2035
#00ebd4
#00ffc4
#008f81
#cbd5e1
#ffffff
#64748b
#94a3b8
#a5b4d0
#ff6b6b
#dc2626
#ef4444
#f87171
#4ade80
#030408
#ffffff
#fff
#1a1a1a
#4285f4
#34a853
#fbbc05
#ea4335
#22c55e
#34d399
#60a5fa
#a78bfa
#ffc107
#10a37f
#d4a017
#f59e0b
#a855f7
#ef4444
#f97316
#e2e8f0
COLORS
while IFS= read -r color; do
    [ -z "$color" ] && continue
    if ! grep -qxF "$color" /tmp/gate-approved.txt 2>/dev/null; then
        [ "$color_fail" -eq 0 ] && echo "FAIL"
        files=$(grep -rl "$color" src/ --include="*.tsx" --include="*.ts" --include="*.css" 2>/dev/null | head -3 | tr '\n' ' ')
        echo "  $color in $files"
        color_fail=1
    fi
done < /tmp/gate-colors.txt
rm -f /tmp/gate-colors.txt /tmp/gate-approved.txt
[ "$color_fail" -eq 0 ] && echo "PASS"
[ "$color_fail" -eq 1 ] && fail=$((fail + 1))

# ── 13. WCAG audit freshness ───────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] WCAG audit freshness... "
AUDIT_FILE=".hermes/wcag-audit"
if [ -f "$AUDIT_FILE" ]; then
    audit_time=$(stat -c %Y "$AUDIT_FILE" 2>/dev/null || echo 0)
    newest_ui=$(find src/components/ src/app/ -name "*.tsx" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -rn | head -1 || echo 0)
    if [ "${newest_ui:-0}" -gt "${audit_time:-0}" ]; then
        echo "FAIL (UI files changed since last WCAG audit — run web-design-guidelines)"
        fail=$((fail + 1))
    else
        echo "PASS"
    fi
else
    echo "FAIL (no .hermes/wcag-audit — run web-design-guidelines)"
    fail=$((fail + 1))
fi

# ── 14. Required skills manifest ────────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Required skills manifest... "
SKILLS_DIR="$HOME/AppData/Local/hermes/skills"
MANIFEST=".hermes/required-skills.json"
if [ -f "$MANIFEST" ]; then
    manifest_fail=0
    # Check it's valid JSON
    python3 -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null || {
        echo "FAIL (invalid JSON)"
        fail=$((fail + 1))
        manifest_fail=1
    }
    if [ "$manifest_fail" -eq 0 ]; then
        # Check all referenced skills exist on disk
        missing_skills=""
        while IFS= read -r skill; do
            skill=$(echo "$skill" | tr -d '\r')
            [ -z "$skill" ] && continue
            # Check both top-level and category subdirectories
            if [ ! -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
                found=0
                for d in "$SKILLS_DIR"/*/; do
                    if [ -f "${d}${skill}/SKILL.md" ]; then
                        found=1; break
                    fi
                done
                if [ "$found" -eq 0 ]; then
                    missing_skills="$missing_skills $skill"
                fi
            fi
        done <<< "$(python3 -c "
import json
data = json.load(open('$MANIFEST'))
all_skills = []
for phase in data:
    if phase.startswith('_'):
        continue
    all_skills.extend(data[phase])
for s in sorted(set(all_skills)):
    print(s)
" 2>/dev/null)"
        if [ -n "$missing_skills" ]; then
            echo "FAIL"
            for ms in $missing_skills; do
                echo "       missing: $ms"
            done
            fail=$((fail + 1))
            manifest_fail=1
        fi
    fi
    [ "$manifest_fail" -eq 0 ] && echo "PASS"
else
    echo "FAIL (no .hermes/required-skills.json)"
    fail=$((fail + 1))
fi

# ── CHECK 15: Model change audit ───────────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Model change audit... "
AUDIT_SCRIPT="$HOME/AppData/Local/hermes/scripts/model-audit.py"
if [ -f "$AUDIT_SCRIPT" ]; then
    AUDIT_OUTPUT=$(python3 "$AUDIT_SCRIPT" 2>/dev/null || true)
    if echo "$AUDIT_OUTPUT" | grep -q "DEAD"; then
        echo "FAIL"
        echo "$AUDIT_OUTPUT" | grep "DEAD" | while read line; do echo "       $line"; done
        fail=$((fail + 1))
    else
        echo "PASS"
    fi
else
    echo "SKIP (model-audit.py not found)"
fi

# ── CHECK 16: Completion contract verification ──────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Completion contract... "
CONTRACT_DIR=".hermes/completion-contracts"
if [ ! -d "$CONTRACT_DIR" ] || [ -z "$(ls -A "$CONTRACT_DIR" 2>/dev/null)" ]; then
    echo "SKIP (no active contract)"
else
    contract_fail=0
    for contract in "$CONTRACT_DIR"/*.md; do
        [ -f "$contract" ] || continue
        contract_name=$(basename "$contract" .md)

        # Verify contract exists and has clauses
        if ! grep -q "^### C[0-9]" "$contract" 2>/dev/null; then
            echo "FAIL ($contract_name: no clauses found)"
            fail=$((fail + 1))
            contract_fail=1
            continue
        fi

        # Check file-exists clauses
        while IFS= read -r filepath; do
            [ -z "$filepath" ] && continue
            if [ ! -f "$filepath" ] && [ ! -d "$filepath" ]; then
                [ "$contract_fail" -eq 0 ] && echo "FAIL"
                echo "       $contract_name: '$filepath' missing"
                contract_fail=1
            fi
        done <<< "$(grep -A1 'Type:.*file-exists' "$contract" | grep 'Check:' | sed 's/.*Check:\s*//' | tr -d '\r' | tr -d '\`')"

        # Check file-contains clauses
        while IFS= read -r check_line; do
            [ -z "$check_line" ] && continue
            filepath=$(echo "$check_line" | cut -d: -f1)
            pattern=$(echo "$check_line" | cut -d: -f2- | sed 's/^ *//')
            if [ -f "$filepath" ]; then
                if ! grep -q "$pattern" "$filepath" 2>/dev/null; then
                    [ "$contract_fail" -eq 0 ] && echo "FAIL"
                    echo "       $contract_name: '$pattern' not found in $filepath"
                    contract_fail=1
                fi
            else
                [ "$contract_fail" -eq 0 ] && echo "FAIL"
                echo "       $contract_name: contract refs missing file '$filepath'"
                contract_fail=1
            fi
        done <<< "$(grep -A1 'Type:.*file-contains' "$contract" | grep 'Check:' | sed 's/.*Check:\s*//' | tr -d '\r' | tr -d '\`')"

        # Check grep clauses
        while IFS= read -r check_line; do
            [ -z "$check_line" ] && continue
            if ! eval "$check_line" 2>/dev/null; then
                [ "$contract_fail" -eq 0 ] && echo "FAIL"
                echo "       $contract_name: '$check_line' returned false"
                contract_fail=1
            fi
        done <<< "$(grep -A1 'Type:.*grep' "$contract" | grep 'Check:' | sed 's/.*Check:\s*//' | tr -d '\r' | tr -d '\`')"
    done
    [ "$contract_fail" -eq 0 ] && echo "PASS"
    [ "$contract_fail" -gt 0 ] && fail=$((fail + 1))
fi

# ── CHECK 17: AGENTS.md health threshold ────────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] AGENTS.md health... "
if [ ! -f "AGENTS.md" ]; then
    echo "SKIP (no AGENTS.md)"
else
    agents_lines=$(wc -l < AGENTS.md | tr -d ' ')
    if [ "$agents_lines" -gt 3000 ]; then
        echo "FAIL ($agents_lines lines — exceeds 3,000 threshold, archive recommended)"
        fail=$((fail + 1))
    elif [ "$agents_lines" -gt 1500 ]; then
        echo "WARN ($agents_lines lines — monitor growth)"
    else
        echo "PASS ($agents_lines lines)"
    fi
fi

# ── CHECK 18: Shared component version drift ─────────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Shared component drift... "
if [ ! -f ".hermes/shared-versions.json" ]; then
    echo "SKIP (no manifest — bootstrap first)"
else
    drift_result=$(python3 -c "
import json, os, re
with open('.hermes/shared-versions.json') as f:
    manifest = json.load(f)
failures = []
for filepath, expected in manifest.get('files', {}).items():
    if not os.path.exists(filepath):
        failures.append(f'{os.path.basename(filepath)}: file not found')
        continue
    with open(filepath, encoding='utf-8') as f:
        content = f.read(200)  # first 200 chars enough for header
    m = re.search(r'v(\d+\.\d+\.\d+)', content)
    if not m:
        failures.append(f'{os.path.basename(filepath)}: missing version header (expected v{expected})')
    elif m.group(1) != expected:
        failures.append(f'{os.path.basename(filepath)}: v{m.group(1)} (expected v{expected})')
if failures:
    print('FAIL')
    for f in failures:
        print(f'       {f}')
else:
    print('PASS')
" 2>/dev/null)
    if echo "$drift_result" | grep -q '^PASS$'; then
        echo "PASS"
    else
        echo "$drift_result"
        fail=$((fail + 1))
    fi
fi

# ── Check 19: Impact audit present (same-date) ─────────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Impact audit for today... "
today_audit="docs/superpowers/specs/$(date +%Y-%m-%d)-impact-audit.md"
if [ -f "$today_audit" ]; then
    echo "PASS"
else
    echo "FAIL (missing — create $today_audit)"
    fail=$((fail + 1))
fi

# ── Check 20: Production-readiness audit validator ────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Production-readiness audit... "
if node .hermes/validate-audit.js docs/superpowers/production-readiness.json > /dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL (run node .hermes/validate-audit.js docs/superpowers/production-readiness.json)"
    fail=$((fail + 1))
fi

# ── Check 21: Pre-completion pipeline (advisory) ──────────────
checks=$((checks + 1))
echo -n "[$checks/$TOTAL] Pre-completion pipeline... "
PIPELINE_ARTIFACT="docs/superpowers/pre-completion-$(date +%Y-%m-%d).json"
if [ -f "$PIPELINE_ARTIFACT" ] && node .hermes/run-pipeline.js --check "$PIPELINE_ARTIFACT" > /dev/null 2>&1; then
    echo "PASS"
else
    echo "WARN (no valid pre-completion artifact — run node .hermes/run-pipeline.js)"
fi

# ── Report ─────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
if [ "$fail" -eq 0 ]; then
    echo "  GATE: PASS — $checks/$checks checks passed"
    echo "═══════════════════════════════════════════"
    exit 0
else
    echo "  GATE: FAIL — $fail/$checks violations found"
    echo "═══════════════════════════════════════════"
    exit 1
fi