#!/bin/sh

# define variables -------------------------------------------------------------
root_dir=$(dirname $0)
entries_dir="$root_dir/content"
built_dir="$root_dir/public"
font_size="20px"
banner_text="John Inman"
favicon_text="🐩"

# start fresh ------------------------------------------------------------------
rm -rf $built_dir

# make favicon -----------------------------------------------------------------
printf '%s' '<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://ww'\
  'w.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size'\
  '=%2290%22>'"$favicon_text"'</text></svg>">' > /tmp/favicon.h

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
    -V fontsize=$font_size \
    "$@"
}

# render entries ---------------------------------------------------------------
entries=
# LC_COLLATE=C sorts by ascii
for dir in $(LC_COLLATE=C ls -rd $entries_dir/*); do
  date=$(basename $dir)
  file=$(ls $dir/*.md)
  [ -f "$file" ] || continue

  mkdir -p $built_dir/$date
  my_pandoc -o $built_dir/$date/index.html "$file"

  for img in $(sed -n 's/.*!\[.*\](\([^)]*\)).*/\1/p' "$file"); do
    cp $dir/$img $built_dir/$date/
  done

  title=$(sed -n '/^# /{ s/^# //p;q; }' "$file")
  entries="$entries<tr><td>$date</td><td><a href=/$date>$title</a></td></tr>"
done

# make toc ---------------------------------------------------------------------
printf '<table>%s</table>\n' "$entries" \
  | my_pandoc --metadata title="$banner_text" -o $built_dir/index.html
