#!/bin/ash

collect_changes() {
	# Remove hashes of deleted or moved files
	# Update hashes of changed files
	for file_hash_file in $(find $INPUT_CACHE_DIR -type f); do
		file_hash="$(basename $file_hash_file)"
		file_location="$(cat $file_hash_file)"

		if [[ ! -e "$file_location" ]]; then
			echo "Removed: $file_location"
			rm "$file_hash_file"
		else
			new_file_hash="$(sha256sum $file_location | awk '{ print $1; }')"
			if [[ "$file_hash" != "$new_file_hash" ]]; then
				mv "$INPUT_CACHE_DIR/$file_hash" "$INPUT_CACHE_DIR/$new_file_hash"
				echo "Changed: $file_location"
				build_pdf "$file_location"
			fi
		fi
	done

	# Add hashes of new files
	for file_location in $(find $INPUT_SOURCE_DIR -type f -name '*.tex'); do
		file_hash="$(sha256sum $file_location | awk '{ print $1; }')"
		if [[ ! -e "$INPUT_CACHE_DIR/$file_hash" ]]; then
			echo "$file_location" > "$INPUT_CACHE_DIR/$file_hash"
			echo "Added: $file_location"
			build_pdf "$file_location"
		fi
	done
}

build_pdf() {
	local file_location="$1"

	cd "$(dirname $file_location)"
	pdflatex -interaction nonstopmode -output-directory "$INPUT_DESTINATION_DIR" "$(basename $file_location)"
}

collect_changes

if [[ $WATCH_MODE == "true" ]]; then
	inotifywait --recursive --monitor --event modify,move,create,delete $INPUT_SOURCE_DIR | \
		while read change; do
			# Debounce 1 second
			timeout 1 cat >/dev/null 2>/dev/null

			collect_changes
		done
fi
