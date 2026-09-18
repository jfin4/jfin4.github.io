#!/bin/sh

# define variables -------------------------------------------------------------
root=$(dirname $0)
source=$root/content
site=$root/public
favicon=🐩
banner="John Inman"

# start fresh ------------------------------------------------------------------
rm -rf $site

# make favicon -----------------------------------------------------------------
printf '%s' '<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://ww'\
  'w.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size'\
  '=%2290%22>'"$favicon"'</text></svg>">' > /tmp/favicon.h

# load google fonts ------------------------------------------------------------
printf '%s' '<link rel="preconnect" href="https://fonts.googleapis.com"><link '\
  'rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="h'\
  'ttps://fonts.googleapis.com/css2?family=Source+Sans+Pro:wght@400;700&family'\
  '=Source+Code+Pro&display=swap" rel="stylesheet">' > /tmp/googlefonts.h

# configure pandoc -------------------------------------------------------------
my_pandoc() {
  pandoc \
    --standalone \
    --include-in-header=/tmp/favicon.h \
    --include-in-header=/tmp/googlefonts.h \
    --math-method=mathjax \
    -V mainfont='Source Sans Pro, sans-serif' \
    -V monofont='Source Code Pro, monospace' \
    -V fontsize='20px' \
    "$@"
}

# render entries ---------------------------------------------------------------
entries=
# LC_COLLATE=C sorts by ascii
for dir in $(LC_COLLATE=C ls -rd $source/*); do
  date=$(basename $dir)
  file=$(ls $dir/*.md)
  [ -f "$file" ] || continue

  mkdir -p $site/$date
  my_pandoc -o $site/$date/index.html "$file"

  for img in $(sed -n 's/.*!\[.*\](\([^)]*\)).*/\1/p' "$file"); do
    cp $dir/$img $site/$date/
  done

  title=$(sed -n '/^# /{ s/^# //p;q; }' "$file")
  entries="$entries<tr><td>$date</td><td><a href=/$date>$title</a></td></tr>"
done

# make toc ---------------------------------------------------------------------
printf '<table>%s</table>\n' "$entries" \
  | my_pandoc --metadata title="$banner" -o $site/index.html
