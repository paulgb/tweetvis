
build/tweetvis.js : src/tweetvis.coffee
	mkdir -p build
	node_modules/.bin/browserify -t coffeeify src/tweetvis.coffee > build/tweetvis.js

serve : build/tweetvis.js
	@echo "Bookmarklet: javascript:(function(){document.body.appendChild(document.createElement('script')).src='https://localhost:8080/tweetvis.js';})();"
	cd build ; ../node_modules/.bin/http-server -S -C ../cert.pem -K ../key.pem

