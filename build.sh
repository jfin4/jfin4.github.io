#!/bin/bash

public=/usr/share/nginx/jfin.net
/usr/bin/rm -r $public/*

# process posts
# ------------------------------------------------------------------------------

entries=""

for dir in posts/*; do
    source=$dir/source.md
    [[ -f $source ]] || continue
    
    # convert
    target=$dir/_public/index.html
    if [[ $source -nt $target ]]; then
        export title=$(head -n1 $source)
        export content=$(pandoc $source)
        [[ -d $dir/_public ]] || mkdir $dir/_public
        envsubst < templates/index.html > $target
    fi

    # copy to temp build dir
    slug=$(head $source | grep -Eo "[0-9]{4}-[0-9]{2}-[0-9]{2}")
    cp -r $dir/_public $public/$slug

    # make index entry
    export date=$slug
    export url=$slug
    export description=$(head -n1 $source)
    entry=$(envsubst < templates/toc.html)
    entries="$entries"$'\n'"$entry"

done

# make index
export title=jfin.net
export content="$entries"
envsubst < templates/index.html > $public/index.html

# process pages
# ------------------------------------------------------------------------------

for dir in pages/*; do
    source=$dir/source.md
    [[ -f $source ]] || continue
    
    # convert
    target=$dir/_public/index.html
    if [[ $source -nt $target ]]; then
        export title=$(basename $dir)
        export content=$(pandoc $source)
        [[ -d $dir/_public ]] || mkdir $dir/_public
        envsubst < templates/index.html > $target
    fi

    # copy to temp build dir
    slug=$(basename $dir)
    cp -r $dir/_public $public/$slug

done

# process root files
# ------------------------------------------------------------------------------

cp -r root/* $public
