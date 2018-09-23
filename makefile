SHELL := /usr/bin/env bash

HTMLVersion := html5

CSSURL:=https://ickc.github.io/markdown-latex-css

# command line arguments
pandocArgCommon := -f markdown+autolink_bare_uris-fancy_lists --toc -V linkcolorblue -V citecolor=blue -V urlcolor=blue -V toccolor=blue -M date="`date "+%B %e, %Y"`"
pandocArgFragment := $(pandocArgCommon)
pandocArgHTML := $(pandocArgFragment) -t $(HTMLVersion) --toc-depth=2 -s -N -c $(CSSURL)/css/common.css -c $(CSSURL)/fonts/fonts.css

# Main Targets ########################################################################################################################################################################################

all: docs/index.html

clean:
	rm -f docs/index.html

# Making dependancies #################################################################################################################################################################################

%.html: %.md
	pandoc $(pandocArgHTML) $< -o $@

# maintenance #########################################################################################################################################################################################

# cleanup markdown
cleanup: style normalize
## Normalize white spaces:
### 1. Add 2 trailing newlines
### 2. transform non-breaking space into (explicit) space
### 3. temporarily transform markdown non-breaking space `\ ` into unicode
### 4. delete all CONSECUTIVE blank lines from file except the first; deletes all blank lines from top and end of file; allows 0 blanks at top, 0,1,2 at EOF
### 5. delete trailing whitespace (spaces, tabs) from end of each line
### 6. revert (3)
normalize:
	find . -maxdepth 2 -mindepth 2 -iname "*.md" | xargs -i -n1 -P8 bash -c 'printf "\n\n" >> "$$0" && sed -i -e "s/ / /g" -e '"'"'s/\\ / /g'"'"' -e '"'"'/./,/^$$/!d'"'"' -e '"'"'s/[ \t]*$$//'"'"' -e '"'"'s/ /\\ /g'"'"' $$0' {}
## pandoc cleanup:
### 1. pandoc from markdown to markdown
### 2. transform unicode non-breaking space back to `\ `
style:
	find . -maxdepth 2 -mindepth 2 -iname "*.md" | xargs -i -n1 -P8 bash -c 'pandoc $(pandocArgMD) -o $$0 $$0 && sed -i -e '"'"'s/ /\\ /g'"'"' $$0' {}
