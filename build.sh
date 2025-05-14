#!/bin/bash

inject_template() {
  cat <<- EOF > "$1"
		<!DOCTYPE html>
		<html lang="en">
		  <head>
		    <meta charset="UTF-8">
		    <meta name="viewport" content="width=device-width, initial-scale=1">
		    <title>$2</title>
		    <link rel="stylesheet" href="/assets/css/style.css">
            <link rel="icon" type="image/png" href="/favicon-96x96.png" sizes="96x96" />
            <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
            <link rel="shortcut icon" href="/favicon.ico" />
            <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
            <link rel="manifest" href="/site.webmanifest" />
		  </head>
		  <body>
		    <header> 
		      <div><a href="/">jfin.net</a></div>
		      <div><a href="/pages/contact">contact</a></div>
		    </header>
		    <main>
		      $3
		    </main>
		  </body>
		</html>
	EOF
}

add_index_entry() {
  read -r -d '' index <<- EOF 
		$index
		<div class="index-entry">
		  <a href="$1"><p>$2<br />
		  <span>$3</span></p></a>
		</div>
	EOF
}

# process contact page
markdown_file="pages/contact/contact.md"
link_path=${markdown_file%/*}
title="contact"
html_file="$link_path/index.html"
if [ "$markdown_file" -nt "$html_file" ]; then
  echo building "$html_file"
  html_content=$(pandoc "$markdown_file")
  inject_template "$html_file" "$title" "$html_content"
fi

# process posts 
$(ls --reverse posts/*/*.md 2> /dev/null) \
    && for markdown_file in $(ls --reverse posts/*/*.md); do 

  # sed commands for title/date assume title block structure:
  #
  # 	::: title-block
  # 	# title
  #
  # 	date (updated)
  # 	:::
  #

  # convert markdown
  link_path=${markdown_file%/*}
  title=$(sed --quiet '2p;2q' "$markdown_file" | cut --characters=3-)
  html_file="$link_path/index.html"
  if [ "$markdown_file" -nt "$html_file" ]; then
    echo building "$html_file"
    html_content=$(pandoc "$markdown_file")
    inject_template "$html_file" "$title" "$html_content"
  fi

  # check date
  article_date=$(sed --quiet '4p;4q' "$markdown_file" | sed -e 's/ (.*//')
  article_date_ymd=$(date -d "$article_date" +'%Y-%m-%d')
  link_path_date=${link_path##*/} # post dirs are dates in yyyy-mm-dd format
  if [ "$article_date_ymd" != "$link_path_date" ]; then
    echo moving posts/"$link_path_date" to posts/"$article_date_ymd"
    echo rerun script to reorder index
    mv posts/"$link_path_date" posts/"$article_date_ymd"
    link_path=posts/"$article_date_ymd"
  fi

  # add index entry
  add_index_entry "$link_path" "$title" "$article_date"

done 

# create index
html_file=index.html
title="jfin.net"
inject_template "$html_file" "$title" "$index"

echo done
