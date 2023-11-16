#!/bin/sh

# File paths
md_content_file="$1"
output_file="${1%/*}/index.html"


# convert md contenct to html
html_content=$(pandoc $md_content_file)

cat << EOF > "$output_file"
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>John Inman</title>
        <link rel="stylesheet" href="/assets/css/style.css">
        <link rel="apple-touch-icon" sizes="180x180" href="/assets/icon/apple-touch-icon.png">
        <link rel="icon" type="image/png" sizes="32x32" href="/assets/icon/favicon-32x32.png">
        <link rel="icon" type="image/png" sizes="16x16" href="/assets/icon/favicon-16x16.png">
        <link rel="manifest" href="/assets/icon/site.webmanifest">
    </head>
    <body>
        <header> 
            <div><a href="/">John Inman</a></div>
            <div><a href="/pages/contact">Contact</a></div>
        </header>
        <main>
            $html_content 
        </main>
    </body>
</html>
EOF




