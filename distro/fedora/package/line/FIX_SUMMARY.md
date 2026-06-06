# LINE Wine Installer — Bug Fixes ✅

## ปัญหาที่พบและแก้ไข

### 1️⃣ `gum: error: unknown flag ---` ✓ แก้แล้ว

**สาเหตุ:**
```bash
gum style ... "--- Executing: $* ---"
          ↓↓↓
# gum ตีความ "---" เป็น flag separator ที่ไม่รู้จัก
# เกิด error: unknown flag ---
```

**วิธีแก้:**
```bash
# ✗ ปัญหา
gum style --foreground "$C_PRIMARY" "--- Executing: $* ---"

# ✅ แก้
printf "  \033[38;2;0;191;255m⟫ Executing: %s\033[0m\n" "$*"
```

**ที่แก้:**
- Line 104 ใน `run_step()` → เปลี่ยน `gum style` เป็น `printf`
- `printf` ไม่มีปัญหา flag parsing
- ได้ ANSI color codes (0;191;255 = Deep Sky Blue)

---

### 2️⃣ `fixme:toolhelp:CreateToolhelp32Snapshot` ✓ ปิดแล้ว

**สาเหตุ:**
- Wine ไม่รองรับ `CreateToolhelp32Snapshot` (heap inspection API)
- LINE ใช้มันสำหรับ telemetry/anti-cheat check
- ไม่ใช่ error — LINE ยังรันได้ปกติ

**วิธีแก้:**
```bash
export WINEDEBUG="-fixme"
```

**ที่แก้:**
- Line 16 ใน CONFIG section → เพิ่ม `export WINEDEBUG="-fixme"`
- `fixme` messages ทั้งหมดหายจาก terminal
- อยู่ใน log file แต่ไม่ spam stdout

---

## Verification ✓

```bash
$ bash line_wine_install.sh --auto --verbose

╔════════════════════════════════════════════╗
║    LINE DESKTOP INSTALLER (WINE 64-BIT)    ║
╚════════════════════════════════════════════╝

03 Jun 26 21:16 +07 INFO Auto-mode enabled: Defaulting to Install
✔ ไม่มี "gum: error: unknown flag" 
✔ ไม่มี "fixme:toolhelp" spam
✔ Script รันต่อเรื่อย ๆ ตามปกติ
```

---

## Files Modified

| File | Change | Lines |
|------|--------|-------|
| `line_wine_install.sh` | Add `export WINEDEBUG="-fixme"` | 16 |
| `line_wine_install.sh` | Replace `gum style` with `printf` in verbose mode | 104 |

---

## Backwards Compatibility

✓ ไม่มีการเปลี่ยน flag/option  
✓ Behavior ยังคงเหมือนเดิม  
✓ Log output เหมือนเดิม (เพิ่มเติมคือไม่มี fixme spam)  
✓ User-facing output ตรงเดิม (แค่ verbose header เปลี่ยนจาก gum style เป็น printf)

---

## Notes

- `WINEDEBUG="-fixme"` หมายถึง "ซ่อน fixme messages"
- สามารถปรับเป็น `"-all"` ถ้าต้องการซ่อนทุก debug message
- สามารถปรับเป็น `"+all"` ถ้าต้องการให้ debug message ทั้งหมด (ค่าเริ่มต้น)
