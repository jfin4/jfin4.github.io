#!/bin/sh

source=content
site=public
icon=🐩
banner="John Inman"
temp=/tmp/favicon.h

root=$(dirname $0)
rm -rf $root/$site

printf '%s' \
  '<link rel="icon" href="data:image/svg+xml,' \
  '<svg xmlns=%22http://www.w3.org/2000/svg%22' \
  ' viewBox=%220 0 100 100%22>' \
  '<text y=%22.9em%22 font-size=%2290%22>' \
  "$icon" \
  '</text></svg>">' \
  > $temp

entries=
for dir in $(LC_COLLATE=C ls -rd $root/$source/*); do
  date=$(basename $dir)
  file=$(ls $dir/*.md)
  [ -f "$file" ] || continue

  mkdir -p $root/$site/$date
  pandoc \
    --standalone \
    --include-in-header=$temp \
    -o $root/$site/$date/index.html \
    "$file"

  for img in $(sed -n 's/.*!\[.*\](\([^)]*\)).*/\1/p' "$file"); do
    cp $dir/$img $root/$site/$date/
  done

  title=$(sed -n '/^# /{ s/^# //p;q; }' "$file")
  entries="$entries<tr><td>$date</td><td><a href=/$date>$title</a></td></tr>"
done

printf '<table>%s</table>\n' "$entries" \
  | pandoc --standalone \
  --metadata title="$banner" \
  --include-in-header=$temp \
  -o $root/$site/index.html
