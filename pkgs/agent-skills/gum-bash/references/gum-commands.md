# Gum Command Reference

Quick lookup for all gum commands, flags, and patterns used in this skill.

---

## gum style — Inline styling

```bash
gum style [OPTIONS] TEXT...

Key flags:
  --foreground "#HEX"          Text color
  --background "#HEX"          Background color
  --border none|normal|rounded|thick|double|hidden
  --border-foreground "#HEX"   Border color
  --padding "V H"              Inner space (e.g. "1 2")
  --margin "V H"               Outer space
  --width N                    Fixed width (important for gum join alignment)
  --align left|center|right
  --bold
  --italic
  --faint                      Dimmed/secondary text
```

---

## gum join — Layout

```bash
gum join --horizontal BLOCK1 BLOCK2 ...   # Side-by-side
gum join --vertical   BLOCK1 BLOCK2 ...   # Stacked
  --align left|center|right               # Alignment of shorter blocks
```

**Critical**: always double-quote styled block variables before passing to `gum join`:
```bash
left="$(gum style --width 20 'Label')"
right="$(gum style 'Value')"
gum join --horizontal "$left" "$right"   # ✔ correct
gum join --horizontal $left $right       # ✗ newlines get stripped
```

---

## gum spin — Spinner

```bash
gum spin --spinner TYPE --title "Message..." -- COMMAND [ARGS...]

Spinner types: line dot minidot jump pulse points globe moon monkey meter hamburger

Key flags:
  --show-output   Pass through command stdout (useful for debug mode)
  --spinner.foreground "#HEX"
  --title.foreground "#HEX"
```

---

## gum log — Structured logging

```bash
gum log [OPTIONS] MESSAGE [KEY VALUE ...]

  --level debug|info|warn|error|fatal
  --structured        Show key=value pairs after message
  --time rfc822       Prepend timestamp
  --prefix STRING     Label log source (e.g. "INSTALL")
```

---

## gum format — Markdown in terminal

```bash
gum format -t markdown <<'EOF'
# Heading
- **bold item**
- *italic item*
`code snippet`
EOF

Modes: -t markdown  (default)
       -t code      (syntax highlighting)
       -t template  (Go templates, {{ Bold "text" }})
       -t emoji     (:rocket: :check: :warning:)
```

---

## gum confirm — Yes/No prompt (interactive only)

```bash
gum confirm "Proceed with deletion?" && rm -rf /tmp/junk || info "Aborted"
# exit 0 = yes, exit 1 = no
```

---

## gum choose — Selection list (interactive only)

```bash
DISTRO=$(echo -e "ubuntu\nfedora\narch" | gum choose)
```

---

## gum input — Text input (interactive only)

```bash
REPO=$(gum input --placeholder "https://github.com/user/repo")
```

---

## gum table — Tabular display

```bash
printf "Name,Version,Status\ngum,0.14,ok\nbash,5.2,ok\n" | gum table
```

---

## Environment Variable Defaults

These set global defaults for all gum calls in the script:

```bash
# Spinner
export GUM_SPIN_SPINNER="line"
export GUM_SPIN_SPINNER_FOREGROUND="#00BFFF"
export GUM_SPIN_TITLE_FOREGROUND="#666666"

# Log
export GUM_LOG_LEVEL="info"           # minimum level shown
export GUM_LOG_TIME="rfc822"          # timestamp format

# Style defaults
export GUM_STYLE_BORDER="normal"
export GUM_STYLE_BORDER_FOREGROUND="#04B575"
```
