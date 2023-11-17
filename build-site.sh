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
		<p><a href="$1">$2</a><br />
		<span class="date">$3</span></p>
	EOF
}

# process posts 
for markdown_file in posts/*/*.md; do
	
	# add index entries
	markdown_content=$(< "$markdown_file")
	path=${markdown_file%/*}
	date=${markdown_content%$'\n':::*} # $'\n' is newline character
	date=${date##*\}$'\n'} 
	title=${markdown_content%% {*} 
	title=${title#* } 
	add_index_entry "$path" "$title" "$date"

	# convert markdown 
	html_file="${markdown_file%/*}/index.html"
	if [ "$markdown_file" -nt "$html_file" ]; then
		html_content=$(pandoc "$markdown_file")
		inject_template "$html_file" "$title" "$html_content"
	fi

done 

# create index
inject_template index.html "John Inman" "$index"
