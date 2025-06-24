#!/bin/sh

project_root=$(realpath ${0%/*})
cd "$project_root"
rm -r public/* > /dev/null 2>&1

# process posts
# ------------------------------------------------------------------------------

dirs=$(echo posts/*)
for dir in $dirs; do
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
    cp -r $dir/_public public/$slug

    # make index entry
    export date=$slug
    export url=$slug
    export description=$(head -n1 $source)
    entry=$(envsubst < templates/toc.html)
    if [[ $dir == ${dir[1]} ]]; then
        entries="$entry"
    else
        entries="$entries$entry"
    fi
done

# make index
export title=jfin.net
export content="$entries"
envsubst < templates/index.html > public/index.html

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
    cp -r $dir/_public public/$slug

done

# process root files
# ------------------------------------------------------------------------------

cp -r root/* public

# sync with server
# ------------------------------------------------------------------------------

server_root=/var/www/jfin.net
if [[ -d $server_root ]]; then
    doas rsync -a --delete public/* $server_root
fi

# finish
# ------------------------------------------------------------------------------

cd - > /dev/null
