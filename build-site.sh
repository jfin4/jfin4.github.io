#!/bin/sh

inject_template() {
    cat <<- EOF > "$1"
		<!DOCTYPE html>
		<html lang="en">
			<head>
				<meta charset="UTF-8">
				<meta name="viewport" content="width=device-width, initial-scale=1">
				<title>$2</title>
				<link rel="stylesheet" href="/assets/css/style.css">
				<link rel="apple-touch-icon" sizes="180x180" href="/assets/icons/apple-touch-icon.png">
				<link rel="icon" type="image/png" sizes="32x32" href="/assets/icons/favicon-32x32.png">
				<link rel="icon" type="image/png" sizes="16x16" href="/assets/icons/favicon-16x16.png">
				<link rel="manifest" href="/assets/icons/site.webmanifest">
			</head>
			<body>
				<header> 
					<div><a href="/">John Inman</a></div>
					<div><a href="/pages/contact">Contact</a></div>
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
			<p><a href="$dir">$title<br />
			<span>$article_date</span></a></p>
		</div>
	EOF
}

make_vars() {
	markdown_file="$1"
	dir=${markdown_file%/*}
	title=$(sed --quiet '2p;2q' "$markdown_file" | cut --characters=3-)
	article_date=$(sed --quiet '4p;4q' "$markdown_file" | sed -e 's/ (.*//')
}

convert_markdown() {
	html_file="$dir/index.html"
	if [ "$markdown_file" -nt "$html_file" ]; then
		echo building "$html_file"
		html_content=$(pandoc "$markdown_file")
		inject_template "$html_file" "$title" "$html_content"
	fi
}

check_date() {
	article_date_ymd=$(date -d "$article_date" +'%Y-%m-%d')
	tail_dir=${dir##*/}
	if [ "$article_date_ymd" != "$tail_dir" ]; then
		echo moving "$dir" to posts/"$article_date_ymd"
		echo rerun script to reorder index
		mv posts/"$tail_dir" posts/"$article_date_ymd"
		dir=posts/"$article_date_ymd"
	fi
}

# process contact page
make_vars pages/contact/contact.md
convert_markdown 

# process posts 
for markdown_file in $(ls -r posts/*/*.md); do
	make_vars "$markdown_file"
	convert_markdown 
	check_date
	add_index_entry
done 

# create index
inject_template index.html "John Inman" "$index"

