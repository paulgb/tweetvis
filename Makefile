
build/tweetvis.js : src/tweetvis.coffee node_modules/
	mkdir -p build
	node_modules/.bin/browserify -t coffeeify src/tweetvis.coffee > build/tweetvis.js

node_modules/ : package.json
	npm install

serve : build/tweetvis.js node_modules/
	@echo "Bookmarklet: (copy this to a browser bookmark)"
	@cat bookmarklet.js
	cd build ; ../node_modules/.bin/http-server -S -C ../keys/cert.pem -K ../keys/key.pem

publish : build/tweetvis.js
	git checkout gh-pages
	cp build/tweetvis.js ./
	git add tweetvis.js
	git commit -m "publish"
	git push
	git checkout master

