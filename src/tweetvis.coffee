
d3 = require 'd3'

window.d3 = d3

# twitter disables the console, but it's useful
clog = (m) ->
    console.__proto__.log.call(console, m)


class TreeBuilder
    changeCallback: null
    root: null
    idMap: {}

    addNode: (node) =>
        if 'parent' not of node
            @root = node
        else
            parent = @idMap[node.parent]
            if 'children' not of parent
                parent.children = []
            parent.children.push(node)
        @idMap[node.id] = node
        @changeCallback @root


class TweetLoader
    tweetCallback: null
    doneCallback: null

    getTweetTree: =>
        @rootLocation = document.location.href
        @addRoot()
        @populateTweetQueue()
        @loadNextTweet()

    addRoot: =>
        tweet = @getMainTweet()
        @tweetCallback tweet

    getMainTweet: =>
        tweetDiv = d3.select('div.permalink-tweet')

        tweet = {}
        tweet.id = tweetDiv.attr('data-tweet-id')
        tweet.content = tweetDiv.select('.tweet-text').text()
        tweet.user = tweetDiv.attr('data-screen-name')
        tweet.avatar = tweetDiv.select('.avatar').attr('src')

        clog tweet
        return tweet

    populateTweetQueue: =>
        # tweetQueue is a list of tweet IDs yet-to-be processed. This
        # method is responsible for initially populating the list.
        tweetQueue = []
        d3.selectAll('.simple-tweet')
          .each -> tweetQueue.push d3.select(this).attr('data-tweet-id')
        @tweetQueue = tweetQueue


    waitForLoad: =>
        # wait for a tweet to load (the navigation event is initiated by
        # the calling code) and then call processTweet
        if document.location.href == @rootLocation
            clog 'waiting...'
            window.setTimeout(@waitForLoad, 1000)
        else
            clog 'loaded!'
            window.setTimeout(@processTweet, 1000)


    processTweet: =>
        # extract data from the tweet, call the callback, and then 
        # call back and navigate to the next tweet
        
        tweet = @getMainTweet()

        parentTweetDiv = d3.select('#ancestors li:last-child div.simple-tweet')
        tweet.parent = parentTweetDiv.attr 'data-tweet-id'

        @tweetCallback tweet

        window.history.back()
        window.setTimeout(@loadNextTweet, 1000)


    loadNextTweet: =>
        # process the next tweet in the queue, with a recursive call
        # so that eventually the whole queue will be processed

        if @tweetQueue.length == 0
            return

        tweetId = @tweetQueue.shift()

        tweetDiv = d3.select('div[data-tweet-id="'+tweetId+'"]')
        
        tweetDiv.node().click()

        detailsLink = tweetDiv.select 'a.permalink-link'
        detailsLink.node().click()
        @waitForLoad()




class TweetVis
    margin: 100

    init: =>
        @makeSVG()

    makeSVG: =>
        d3.select('#tweetvis_svg').remove()
        container = d3.select('body')
        @width = window.innerWidth
        @height = window.innerHeight

        @svg = container.append('svg:svg')
        @svg
            .attr('id', 'tweetvis_svg')
            .style('position', 'fixed')
            .style('left', 0)
            .style('top', 0)
            .style('bottom', 0)
            .style('right', 0)
            .style('z-index', 1001)
            .attr('viewBox', "0 0 #{@width} #{@height}")
            
        @svg.append('defs')
            .append('clipPath').attr('id', 'roundEdges')
            .append('rect').attr('width', '48px').attr('height', '48px')
            .attr('x', '-24px').attr('y', '-24px')
            .attr('rx', 8)

        @svg.append('rect')
            .attr('x', -2500)
            .attr('y', -2500)
            .attr('width', 5000)
            .attr('height', 5000)
            .style('fill', 'white')

        @svg.append('g')
            .attr('id', 'edges')

        @svg.append('g')
            .attr('id', 'nodes')


    drawTree: (root) =>
        margin = @margin
        tree = d3.layout.tree().size([@width - 2*@margin, @height - 2*@margin])
        layout = tree.nodes(root)
        links = tree.links(layout)

        nodeGroup = @svg.select('#nodes').selectAll('g')
           .data(layout, (d) -> d.id)

        enterNodes = nodeGroup.enter()
                .append('g')
                .attr('transform', (d) -> "translate(0 0)")

        enterNodes.append('title')
            .text((d) -> "#{d.user}: #{d.content}")

        enterNodes.append('image')
                .attr('xlink:href', (d) -> d.avatar)
                .attr('height', '48px')
                .attr('width', '48px')
                .attr('x', '-24px')
                .attr('y', '-24px')
                .attr('clip-path', 'url(#roundEdges)')

        nodeGroup
            .attr('transform', (d) -> "translate(#{d.x+margin} #{d.y+margin})")

        edgeToPath = ({source, target}) =>
            d3.svg.line().x((d) => d.x + @margin)
                         .y((d) => d.y + @margin)
                         .interpolate('linear')([source, target])

        pathGroup = @svg.select('#edges').selectAll('path')
           .data(links, (d) -> d.target.id)

        pathGroup
           .enter()
                .append('path')
                .attr('d', (x) -> edgeToPath(x))
                .attr('stroke', 'black')

        pathGroup
                .attr('d', (x) -> edgeToPath(x))
        

tweetVis = new TweetVis()
tweetVis.init()

treeBuilder = new TreeBuilder()
treeBuilder.changeCallback = tweetVis.drawTree

tweetLoader = new TweetLoader()
tweetLoader.tweetCallback = treeBuilder.addNode
tweetLoader.getTweetTree()

