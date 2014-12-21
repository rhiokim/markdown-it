PATH        := ./node_modules/.bin:${PATH}

NPM_PACKAGE := $(shell node -e 'process.stdout.write(require("./package.json").name)')
NPM_VERSION := $(shell node -e 'process.stdout.write(require("./package.json").version)')

TMP_PATH    := /tmp/${NPM_PACKAGE}-$(shell date +%s)

REMOTE_NAME ?= origin
REMOTE_REPO ?= $(shell git config --get remote.${REMOTE_NAME}.url)

CURR_HEAD   := $(firstword $(shell git show-ref --hash HEAD | cut -b -6) master)
GITHUB_PROJ := https://github.com//markdown-it/${NPM_PACKAGE}


demo: lint
	rm -rf ./demo
	mkdir ./demo
	./support/demodata.js > ./demo/sample.json
	jade --pretty --obj ./demo/sample.json --out ./demo ./support/demo/index.jade
	stylus --use autoprefixer-stylus --out ./demo ./support/demo/index.styl
	cp ./support/demo/index.js ./demo
	cp ./dist/markdown-it.js ./demo
	rm -rf ./demo/sample.json

gh-pages: browserify demo
	rm -rf ./demo-web
	cp -r ./demo ./demo-web
	cp ./dist/markdown-it.js ./demo-web
	sed -i "s|../dist|.|" ./demo-web/index.html
	cp ./support/demo_readme.md ./demo-web/README.md
	touch ./demo-web/.nojekyll
	cd ./demo-web \
		&& git init . \
		&& git add . \
		&& git commit -m "Auto-generate demo" \
		&& git remote add origin git@github.com:markdown-it/markdown-it.github.io.git \
		&& git push --force origin master
	rm -rf ./demo-web

lint:
	eslint --reset .

test: lint
	NODE_ENV=test mocha -R spec
	echo "CommonMark stat:\n"
	./support/specsplit.js test/fixtures/commonmark/spec.txt

coverage:
	rm -rf coverage
	istanbul cover node_modules/.bin/_mocha

test-ci: lint
	istanbul cover ./node_modules/mocha/bin/_mocha --report lcovonly -- -R spec && cat ./coverage/lcov.info | ./node_modules/coveralls/bin/coveralls.js && rm -rf ./coverage

publish:
	@if test 0 -ne `git status --porcelain | wc -l` ; then \
		echo "Unclean working tree. Commit or stash changes first." >&2 ; \
		exit 128 ; \
		fi
	@if test 0 -ne `git fetch ; git status | grep '^# Your branch' | wc -l` ; then \
		echo "Local/Remote history differs. Please push/pull changes." >&2 ; \
		exit 128 ; \
		fi
	@if test 0 -ne `git tag -l ${NPM_VERSION} | wc -l` ; then \
		echo "Tag ${NPM_VERSION} exists. Update package.json" >&2 ; \
		exit 128 ; \
		fi
	git tag ${NPM_VERSION} && git push origin ${NPM_VERSION}
	npm publish ${GITHUB_PROJ}/tarball/${NPM_VERSION}

browserify:
	rm -rf ./dist
	mkdir dist
	# Browserify
	( printf "/*! ${NPM_PACKAGE} ${NPM_VERSION} ${GITHUB_PROJ} @license MIT */" ; \
		browserify -r ./ -s markdownit \
		) > dist/markdown-it.js
	# Minify
	uglifyjs dist/markdown-it.js -b beautify=false,ascii-only=true -c -m \
		--preamble "/*! ${NPM_PACKAGE} ${NPM_VERSION} ${GITHUB_PROJ} @license MIT */" \
		> dist/markdown-it.min.js

todo:
	grep 'TODO' -n -r ./lib 2>/dev/null || test true


.PHONY: publish lint test gh-pages todo demo coverage
.SILENT: help lint test todo
