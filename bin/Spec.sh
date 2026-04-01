#!/bin/bash

MASTER_LANG="en"   # change master language
TARGET_LANG="en"   # target translation language, can be different if needed

cat <<EOF > .po4a.cfg
[po4a_langs] $TARGET_LANG
[po4a_paths] po/content.pot \$lang:po/content.\$lang.po

[options] opt:"--verbose"
[options] opt:"--keep=80"
[options] opt:"--package-name='ALT Linux Space Docs'" 
[options] opt:"--package-version=1.0" 
[options] opt:"--copyright-holder='ALT Linux Space Docs Contributors'"
[options] opt:"--addendum-charset=UTF-8" 
[options] opt:"--localized-charset=UTF-8" 
[options] opt:"--master-charset=UTF-8" 
[options] opt:"--master-language=$MASTER_LANG" 
[options] opt:"--porefs=file" 
[options] opt:"--msgmerge-opt='--no-wrap'" 
[options] opt:"--wrap-po=newlines"

[po4a_alias:markdown] text opt:"--option markdown"
EOF

find src/$MASTER_LANG \( -type f -name '*.md' -o -type f -name '.*.md' \) | while read -r file; do
  relative_path=${file#src/$MASTER_LANG/}
  echo "[type: markdown] $file \$lang:src/\$lang/$relative_path" >> .po4a.cfg
done

po4a .po4a.cfg
