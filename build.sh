#!/bin/sh

root=$(dirname $0)
source=$root/content
site=$root/public
icon=🐩
banner="John Inman"
temp=/tmp/favicon.h

rm -rf $site

printf '%s' \
  '<link rel="icon" href="data:image/svg+xml,' \
  '<svg xmlns=%22http://www.w3.org/2000/svg%22' \
  ' viewBox=%220 0 100 100%22>' \
  '<text y=%22.9em%22 font-size=%2290%22>' \
  "$icon" \
  '</text></svg>">' \
  > $temp

my_pandoc() {
  pandoc \
    --standalone \
    --include-in-header=$temp \
    --math-method=mathjax \
    -V mainfont='Source Sans Pro, Helvetica, Arial, sans-serif' \
    -V monofont='Source Code Pro, Courier New, Courier, monospace' \
    "$@"
}

entries=
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

printf '<table>%s</table>\n' "$entries" \
  | my_pandoc --metadata title="$banner" -o $site/index.html
