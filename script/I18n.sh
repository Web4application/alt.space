#!/bin/bash

# --- Configuration ---
SRC_LANG="en"                       # English source
TARGET_LANGS=("ru" "fr" "de")       # Target languages
PO4A_CFG=".po4a.cfg"
GIT_COMMIT_MSG="Update translations and Markdown files"
REPORT_DIR="translation_reports"

mkdir -p "$REPORT_DIR"

# --- Create / overwrite po4a config ---
cat <<EOF > "$PO4A_CFG"
[po4a_langs] ${TARGET_LANGS[*]}
[po4a_paths] po/content.pot \$lang:po/content.\$lang.po

[options] opt:"--verbose"
[options] opt:"--keep=80"
[options] opt:"--package-name='ALT Linux Space Docs'"
[options] opt:"--package-version=1.0"
[options] opt:"--copyright-holder='ALT Linux Space Docs Contributors'"
[options] opt:"--addendum-charset=UTF-8"
[options] opt:"--localized-charset=UTF-8"
[options] opt:"--master-charset=UTF-8"
[options] opt:"--master-language=$SRC_LANG"
[options] opt:"--porefs=file"
[options] opt:"--msgmerge-opt='--no-wrap'"
[options] opt:"--wrap-po=newlines"

[po4a_alias:markdown] text opt:"--option markdown"
EOF

# --- Add all Markdown files from source language ---
find src/$SRC_LANG \( -type f -name '*.md' -o -type f -name '.*.md' \) | while read -r file; do
    relative_path=${file#src/$SRC_LANG/}
    echo "[type: markdown] $file \$lang:src/\$lang/$relative_path" >> "$PO4A_CFG"
done

# --- Generate/update .po template ---
po4a "$PO4A_CFG"

# --- Smart: check missing translations & create report ---
MISSING=0
for lang in "${TARGET_LANGS[@]}"; do
    REPORT_FILE="$REPORT_DIR/missing_$lang.txt"
    > "$REPORT_FILE"

    if [ ! -f "po/content.$lang.po" ]; then
        echo "⚠️ Translation file po/content.$lang.po does not exist yet." | tee -a "$REPORT_FILE"
        MISSING=1
        continue
    fi

    # Extract untranslated strings
    awk '
        /^msgid / { msgid=$0 }
        /^msgstr ""/ { print msgid }
    ' "po/content.$lang.po" > "$REPORT_FILE"

    UNTRANSLATED_COUNT=$(wc -l < "$REPORT_FILE")
    if [ "$UNTRANSLATED_COUNT" -gt 0 ]; then
        echo "⚠️ $UNTRANSLATED_COUNT untranslated strings in po/content.$lang.po" | tee -a "$REPORT_FILE"
        MISSING=1
    else
        echo "✅ All strings translated for $lang" > "$REPORT_FILE"
    fi
done

# --- Generate translated Markdown only if all strings are translated ---
if [ "$MISSING" -eq 0 ]; then
    for lang in "${TARGET_LANGS[@]}"; do
        mkdir -p "src/$lang"
        po4a --master "src/$SRC_LANG" --translations "po/content.$lang.po" --destination "src/$lang"
    done
    echo "✅ All translations complete. Markdown files generated."
else
    echo "❗ Some translations are missing. Check the report in $REPORT_DIR"
fi

# --- Git integration ---
git add po/*.po "$REPORT_DIR"
for lang in "${TARGET_LANGS[@]}"; do
    git add "src/$lang"
done

if ! git diff --cached --quiet; then
    git commit -m "$GIT_COMMIT_MSG"
    echo "✅ Changes committed to Git."
else
    echo "ℹ️ No changes to commit."
fi

# Optional: uncomment to automatically push
# git push origin main
