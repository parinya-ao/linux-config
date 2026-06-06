# LINE Wine Installer - Gum CLI Fixes

## Issue
The script was throwing `gum: error: unknown flag ---` errors when running in verbose mode.

## Root Cause
Line 103 was passing `"--- Executing: $* ---"` to `gum style`, which incorrectly interpreted the `---` as a flag separator, causing parsing errors.

## Fixes Applied

### Fix 1: Verbose Command Display (Line 103)
**Before:**
```bash
gum style --foreground "$C_PRIMARY" "--- Executing: $* ---"
```

**After:**
```bash
gum style --foreground "$C_PRIMARY" --border normal --border-foreground "$C_MUTED" --padding "0 1" "Executing: $*"
```

**Benefits:**
- Removes problematic `---` that was interpreted as a flag
- Adds visual styling with border and padding
- More polished output in verbose mode

### Fix 2: Error Output Headers (Lines 119, 121)
**Before:**
```bash
gum style --foreground "$C_DANGER" "━━ COMMAND OUTPUT ━━"
gum style --foreground "$C_DANGER" "━━ ERROR OUTPUT ━━"
```

**After:**
```bash
gum style --foreground "$C_DANGER" --bold "COMMAND OUTPUT"
gum style --foreground "$C_DANGER" --bold "ERROR OUTPUT"
```

**Benefits:**
- Removed UTF-8 box-drawing characters that caused encoding issues
- Added `--bold` flag for better visual hierarchy
- Cleaner, more readable output

## Testing
✅ Script now runs without `gum` parsing errors
✅ Verbose mode displays correctly formatted output
✅ Error handling displays properly styled sections

## Files Modified
- `line_wine_install.sh` - 3 fixes applied

## Notes
- The script already follows the gum-bash design system guidelines
- All color tokens are properly defined at the top
- Layer architecture (UI primitives, runners, tasks, orchestration) is well-structured
- Automation-safe guards are in place with idempotent checks
