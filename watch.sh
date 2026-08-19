#!/bin/ash

collect_changes() {
	# Remove hashes of deleted or moved files
	# Update hashes of changed files
	find "$INPUT_CACHE_DIR" -type f | while IFS= read -r file_hash_file; do
		file_hash="$(basename "$file_hash_file")"
		file_location="$(cat "$file_hash_file")"

		if [ ! -e "$file_location" ]; then
			echo "Removed: $file_location"
			rm "$file_hash_file"
		else
			new_file_hash="$(sha256sum "$file_location" | awk '{ print $1; }')"
			if [ "$file_hash" != "$new_file_hash" ]; then
				mv "$INPUT_CACHE_DIR/$file_hash" "$INPUT_CACHE_DIR/$new_file_hash"
				echo "Changed: $file_location"
				build_pdf "$file_location"
			fi
		fi
	done

	# Add hashes of new files
	find "$INPUT_SOURCE_DIR" -type f -name '*.tex' | while IFS= read -r file_location; do
		file_hash="$(sha256sum "$file_location" | awk '{ print $1; }')"
		if [ ! -e "$INPUT_CACHE_DIR/$file_hash" ]; then
			echo "$file_location" > "$INPUT_CACHE_DIR/$file_hash"
			echo "Added: $file_location"
			build_pdf "$file_location"
		fi
	done
}

# Runs in a subshell so the cd below cannot leak into the caller.
build_pdf() (
	file_location="$1"
	file_name="$(basename "$file_location")"
	log_file="$INPUT_DESTINATION_DIR/${file_name%.tex}.log"

	cd "$(dirname "$file_location")" || return 1
	pdflatex -interaction nonstopmode -output-directory "$INPUT_DESTINATION_DIR" "$file_name"

	# \ref, \pageref and the table of contents resolve via .aux/.toc, which only
	# exist after a first pass. Rerun while LaTeX reports the results are stale;
	# a growing TOC can shift page numbers, so allow up to two extra passes.
	attempt=0
	while [ "$attempt" -lt 2 ] && grep -qE 'Rerun to get|Rerun LaTeX' "$log_file" 2>/dev/null; do
		echo "Rerunning pdflatex: $file_location"
		pdflatex -interaction nonstopmode -output-directory "$INPUT_DESTINATION_DIR" "$file_name"
		attempt=$((attempt + 1))
	done
)

collect_changes

if [ "$WATCH_MODE" = "true" ]; then
	inotifywait --recursive --monitor --event modify,move,create,delete "$INPUT_SOURCE_DIR" | \
		while read change; do
			# Debounce 1 second
			timeout 1 cat >/dev/null 2>/dev/null

			collect_changes
		done
fi
