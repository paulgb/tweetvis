
d3 = require 'd3'

window.d3 = d3

# twitter disables the console, but it's useful
clog = (m) ->
    console.__proto__.log.call(console, m)

backdrop = (elem) ->
    {height, width} = elem.node().getBBox()
    p = d3.select(elem.node().parentNode)
    p.insert('rect', ':first-child')
        .classed('hoverReveal', true)
        .attr('width', width + 8)
        .attr('height', height + 8)
        .attr('x', '24px')
        .attr('y', '-32px')
        .attr('rx', 5)
        .attr('fill', 'white')

wrap = (text, width) ->
  # adapted for CoffeeScript from http://bl.ocks.org/mbostock/7555321
  text.each ->
    text = d3.select this
    words = text.text().split(/\s+/).reverse()
    line = []
    lineNumber = 0
    lineHeight = 1.1 # ems
    dy = 0
    y = '-14px'
    tspan = text.text(null)
                .append("tspan")
                .attr("x", '28px')
                .attr("y", y)
                .attr("dy", dy + "em")
                .style('alignment-baseline', 'before-text')

    while word = words.pop()
        line.push(word)
        tspan.text(line.join(" "))
        if tspan.node().getComputedTextLength() > width
            line.pop()
            tspan.text(line.join(" "))
            line = [word]
            tspan = text.append("tspan")
                        .attr("x", '28px')
                        .attr("y", y)
                        .attr("dy", ++lineNumber * lineHeight + dy + "em")
                        .text(word)


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
        @scrollToBottom()

    doneScrolling: =>
        @populateTweetQueue()
        @loadNextTweet()

    scrollToBottom: =>
        tle = d3.select '.timeline-end'
        if tle.classed 'has-more-items'
            clog 'scrolling'
            window.scrollBy 0, 10000
            setTimeout @scrollToBottom, 1000
        else
            clog 'done scrolling'
            @doneScrolling()

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
          #.each -> tweetQueue.push d3.select(this).attr('data-tweet-id')
            .each ->
                this.click()
                noe = d3.select(this).select('a.permalink-link').node()
                tweetQueue.push noe
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

        cf = @tweetQueue.shift()
        clog cf
        cf.click()
        clog 'here1'

        #tweetDiv = d3.select('div[data-tweet-id="'+tweetId+'"]')
        
        #tweetDiv.click()

        #detailsLink = d3.select(tweetDiv).select 'a.permalink-link'
        #detailsLink.node().click()

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
            
        @svg.append('style')
            .text('''
            
            #details rect.hoverCapture {
                opacity: 0;
            }

            #details g .hoverReveal {
                opacity: 0;
            }

            #details g:hover .hoverReveal {
                opacity: 0.8;
            }

            ''')

        @svg.append('rect')
            .attr('x', -2500)
            .attr('y', -2500)
            .attr('width', 5000)
            .attr('height', 5000)
            .style('fill', '#ddd')

        @svg.append('g')
            .attr('id', 'edges')

        @svg.append('g')
            .attr('id', 'nodes')

        @svg.append('g')
            .attr('id', 'details')



    drawTree: (root) =>
        margin = @margin
        tree = d3.layout.tree().size([@width - 2*@margin, @height - 2*@margin])
        layout = tree.nodes(root)
        links = tree.links(layout)

        nodeGroup = @svg.select('#nodes').selectAll('g')
           .data(layout, (d) -> d.id)


        enterNodes = nodeGroup.enter()
                .append('g')

        nodeGroup
            .attr('transform', (d) -> "translate(#{d.x+margin} #{d.y+margin})")

        enterNodes.append('title')
            .text((d) -> "#{d.user}: #{d.content}")

        enterNodes.append('image')
                .attr('xlink:href', (d) -> d.avatar)
                .attr('height', '48px')
                .attr('width', '48px')
                .attr('x', '-24px')
                .attr('y', '-24px')

        enterNodes.append('rect')
                .attr('x', '-24px')
                .attr('y', '-24px')
                .attr('height', '48px')
                .attr('width', '48px')
                .attr('stroke', 'white')
                .attr('stroke-width', '4px')
                .attr('rx', 5)
                .attr('fill', 'none')



        detailsGroup = @svg.select('#details').selectAll('g')
            .data(layout, (d) -> d.id)

        detailsEnter = detailsGroup.enter().append('g')
        
        detailsEnter.append('text')
            .classed('hoverReveal', true)
            .text((d) -> d.content)
            .call(wrap, 200)
            .call(backdrop)

        detailsEnter.append('rect')
            .classed('hoverCapture', true)
            .attr('x', '-24px')
            .attr('y', '-24px')
            .attr('height', '48px')
            .attr('width', '48px')
            .attr('stroke', 'white')
            .attr('stroke-width', '4px')
            .attr('rx', 5)
            .attr('fill', 'white')


        detailsGroup.attr('transform', (d) -> "translate(#{d.x+margin} #{d.y+margin})")
           

        edgeToPath = ({source, target}) =>
            d3.svg.line().x((d) => d.x + @margin)
                         .y((d) => d.y + @margin)
                         .interpolate('linear')([source, target])

        pathGroup = @svg.select('#edges').selectAll('path')
           .data(links, (d) -> d.target.id)

        pathGroup
            .attr('d', (x) -> edgeToPath(x))

        pathGroup
           .enter()
                .append('path')
                .attr('d', (x) -> edgeToPath(x))
                .attr('stroke', 'white')
                .attr('stroke-width', '8px')

        

tweetVis = new TweetVis()
tweetVis.init()

treeBuilder = new TreeBuilder()
treeBuilder.changeCallback = tweetVis.drawTree

tweetLoader = new TweetLoader()
tweetLoader.tweetCallback = treeBuilder.addNode
tweetLoader.getTweetTree()

