#!/bin/bash

# about
source=pages/about/about.md
target=pages/about/public/index.html
if [[ $source -nt $target ]]; then
    export title=about
    export content=$(pandoc $source)
    envsubst < templates/index.html > $target
fi
rsync -a --delete pages/about/public/ public/about

# posts 
for source in posts/*/*.md; do 
    [[ $source = posts/*/*.md ]] && break
    target=${source%/*}/public/index.html
    if [[ $source -nt $target ]]; then
        export title=$(head -n1 $source)
        export content=$(pandoc $source)
        envsubst < templates/index.html > $target
    fi
    date=$(grep -o -e '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' $source)
    rsync -a --delete ${source%/*}/public/ posts/public/$date
done 
rsync -a --delete posts/public/ public/posts

# index
toc=""
for post in posts/public/*; do
    [[ $post = posts/public/* ]] && break
    export date=${post##*/}
    export url=posts/$date
    export title=$(grep '<title>' $post/index.html | sed -e 's#.*>\(.*\)<.*#\1#')
    toc="$toc"$'\n'$(envsubst < templates/toc.html)
done
export title=jfin.net
export content="$toc"
envsubst < templates/index.html > public/index.html
