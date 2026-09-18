#!/bin/sh
rm -rf public

printf '%s\n' \
  '<link rel="icon" href="data:image/svg+xml,'\
  '<svg xmlns=%22http://www.w3.org/2000/svg%22'\
  ' viewBox=%220 0 100 100%22>'\
  '<text y=%22.9em%22 font-size=%2290%22>ji</text></svg>">' \
  > /tmp/fav.h

entries=
for dir in entries/*; do
    date=$(basename $dir)
    for source in $dir/*.md; do break; done
    [ -f "$source" ] || continue
    title=$(sed -n '/^# /{s/^# //p;q}' "$source")

    mkdir -p public/$date
    pandoc --standalone --include-in-header=/tmp/fav.h \
        -o public/$date/index.html "$source"

    for img in $(sed -n 's/.*!\[.*\](\([^)]*\)).*/\1/p' "$source"); do
        cp $dir/$img public/$date/
    done

    entries="$entries<tr><td>$date</td><td><a href=/$date>$title</a></td></tr>"
done

printf '<table>%s</table>\n' "$entries" \
  | pandoc --standalone \
        --metadata title="John Inman" \
        --include-in-header=/tmp/fav.h -f html \
        -o public/index.html
