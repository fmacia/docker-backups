# Checks script code
.PHONY: shellcheck
shellcheck:
	docker run --rm -v "$(PWD):/mnt" koalaman/shellcheck:stable -x create_backups.sh
