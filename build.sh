#!/bin/sh

source=content
site=public
icon=ji

root=${0%/*}
rm -rf $root/$site

printf '%s' \
  '<link rel="icon" href="data:image/svg+xml,' \
  '<svg xmlns=%22http://www.w3.org/2000/svg%22' \
  ' viewBox=%220 0 100 100%22>' \
  '<text y=%22.9em%22 font-size=%2290%22>' \
  "$icon" \
  '</text></svg>">' \
  > /tmp/fav.h

entries=
for dir in $root/$source/*; do
  date=${dir##*/}
  for file in $dir/*.md; do break; done
  [ -f "$file" ] || continue
  title=$(sed -n '/^# /{s/^# //p;q}' "$file")

  mkdir -p $root/$site/$date
  pandoc \
    --standalone \
    --include-in-header=/tmp/fav.h \
    -o $root/$site/$date/index.html \
    "$file"

  for img in $(sed -n 's/.*!\[.*\](\([^)]*\)).*/\1/p' "$file"); do
    cp $dir/$img $root/$site/$date/
  done

  entries="$entries<tr><td>$date</td><td><a href=/$date>$title</a></td></tr>"
done

printf '<table>%s</table>\n' "$entries" \
  | pandoc --standalone \
  --metadata title="John Inman" \
  --include-in-header=/tmp/fav.h \
  -o $root/$site/index.html
