#!/usr/bin/env -i bash

source_files=$(find content -name '*.md')
for source in $source_files; do
    dir=$(dirname $source)
    target=$dir/public/index.html
    if [[ $source -nt $target ]]; then
        if [[ $target =~ '/about/' ]]; then
            title=about
            slug=about
        else
            title=$(head -n1 $source)
            slug=$(head $source | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        fi
        content=$(pandoc $source)
        export title content
        [[ -d $dir/public ]] || mkdir $dir/public
        envsubst < templates/index.html > $target
        rsync -a --delete $dir/public/ content/public/$slug
    fi
done 
rsync -a --delete content/public/ public/content

toc=""
posts=$(find content/public | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}$')
for post in $posts; do
    date=$(basename $post)
    url=/content/$date
    description=$(grep -Po '(?<=<title>).*?(?=</title>)' $post/index.html)
    export date url description
    toc_entry=$(envsubst < templates/toc.html)
    toc="$toc"$'\n'$toc_entry
done
export title=jfin.net
export content="$toc"
envsubst < templates/index.html > public/index.html
