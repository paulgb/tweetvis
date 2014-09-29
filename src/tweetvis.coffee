
d3 = require 'd3'

# twitter disables the console, but it's useful
clog = (m) ->
    console.__proto__.log.call(console, m)


# colours for the reply times
timeColors =
    intervals: [
        300
        600
        3600
        10800
    ]
    humanIntervals: [
        '5 min'
        '10 min'
        '1 hour'
        '3 hours+'
    ]
    colors: [
        '#FA5050'
        '#E9FA50'
        '#F5F1D3'
        '#47D8F5'
    ]

tooltip = (tweet) ->
    # show a tooltip on tweet roll-over
    
    x = d3.select(this).attr('x')
    y = d3.select(this).attr('y')

    imageSize = 48
    margin = 8

    d3.select('#tweetPopup').remove()

    apop = d3.select('svg').append('a')
            .attr('id', 'tweetPopup')
            .attr('xlink:href', tweet.url)
            .attr('target', '_blank')
            .style('text-decoration', 'none')

    tpop = apop.append('g')
            .attr('opacity', 0)

    text = tpop.append('text').text(tweet.content)
            .attr('transform', "translate(#{imageSize+2*margin} 20)")

    image = tpop.append('image')
            .attr('xlink:href', tweet.avatar)
            .attr('height', imageSize)
            .attr('width', imageSize)
            .attr('x', margin)
            .attr('y', margin)

    user = tpop.append('text')
        .text("@#{tweet.name}")
        .attr('font-weight', 'bold')
        .attr('y', 12+margin)
        .attr('x', imageSize + 2*margin)

    wrap(text, 250)

    {height, width} = tpop.node().getBBox()
    console.log height, width, x, y

    hideTooltip = ->
        apop.transition().duration(200)
            .attr('opacity', 0).remove()

    tpop.insert('rect', ':first-child')
        .attr('width', width + 2*margin)
        .attr('height', height + 2*margin)
        .attr('fill', 'white')
        .attr('rx', 5)
        .attr('opacity', 0.9)
        .on('mouseover', hideTooltip)

    x -= (width/2 + margin)
    y -= (height/2 + margin)

    sinkSize = 24
    tpop.append('rect')
        .attr('width', sinkSize)
        .attr('height', sinkSize)
        .attr('x', width/2 + margin - sinkSize/2)
        .attr('y', height/2 + margin - sinkSize/2)
        .style('cursor', 'none')
        .attr('opacity', 0)
        .on('mouseleave', hideTooltip)

    tpop.attr('transform', "translate(#{x} #{y})")
    tpop.transition().duration(200).attr('opacity', 1)
    

wrap = (text, width) ->
    # wrap text inside a box
    # adapted for CoffeeScript from http://bl.ocks.org/mbostock/7555321
    words = text.text().split(/\s+/).reverse()
    line = []
    lineNumber = 0
    lineHeight = 1.1 # ems
    dy = 1.1
    tspan = text.text(null)
                .append("tspan")
                .attr("dy", dy + "em")

    while word = words.pop()
        line.push(word)
        tspan.text(line.join(" "))
        if tspan.node().getComputedTextLength() > width
            line.pop()
            tspan.text(line.join(" "))
            line = [word]
            tspan = text.append("tspan")
                        .attr("x", '0px')
                        .attr("dy", dy + 'em')
                        .text(word)


class LoadingIndicator
    element: null

    constructor: (parent) ->
        @element = parent.append('p')
            .style('position', 'absolute')
            .style('bottom', '20px')
            .style('right', '20px')
            .style('color', '#ddd')

    updateProgress: (num, denom) =>
        @element.text "Loading (#{num}/#{denom})"

    done: =>
        @element.remove()


class TreeBuilder
    changeCallback: null
    root: null
    idMap: {}
    maxDepth: 0
    widthMap: {}
    maxWidth: 0

    addNode: (node) =>
        if not @root?
            @root = node
            node.depth = 0
        else
            parent = @idMap[node.parent]
            if not parent?
                return
            node.depth = parent.depth + 1
            if 'children' not of parent
                parent.children = []
            parent.children.push(node)

        if not @widthMap[node.depth]?
            @widthMap[node.depth] = 0
        @widthMap[node.depth] += 1
        @maxWidth = Math.max @widthMap[node.depth], @maxWidth
        @maxDepth = Math.max node.depth, @maxDepth
        @idMap[node.id] = node
        @changeCallback @root, @maxWidth, @maxDepth


class TweetLoader
    tweetCallback: null
    doneCallback: null
    statusCallback: null
    progNum: 0
    progDenom: 1

    testTweet: =>
        not d3.select('.permalink-tweet').empty()


    getTweetTree: =>
        tweetDiv = d3.select '.permalink-tweet'
        user = tweetDiv.attr 'data-screen-name'
        tweetId = tweetDiv.attr 'data-tweet-id'
        @tweetQueue = []
        @getConversation user, tweetId

    
    processConversation: =>
        tweet = @tweetQueue.shift()
        if tweet?
            [tweetId, user] = tweet
            url = "/#{user}/status/#{tweetId}"
            d3.json(url)
                .header('x-push-state-request', 'true')
                .get (error, data) =>
                    parser = new window.DOMParser()
                    doc = parser.parseFromString data.page, 'text/html'
                    doc = d3.select(doc)

                    tweet = {}
                    parentDiv = doc.select('#ancestors li:last-child div.simple-tweet')
                    if not parentDiv.empty()
                        tweet.parent = parentDiv.attr('data-tweet-id')
                    tweetDiv = doc.select('.permalink-tweet')
                    tweet.id = tweetDiv.attr('data-tweet-id')
                    tweet.user = tweetDiv.attr('data-screen-name')
                    tweet.content = tweetDiv.select('.tweet-text').text()
                    tweet.avatar = tweetDiv.select('.avatar').attr('src')
                    tweet.name = tweetDiv.attr('data-name')
                    tweet.time = parseInt(tweetDiv.select('._timestamp').attr('data-time'))
                    tweet.url = "http://twitter.com/#{tweet.user}/status/#{tweet.id}"

                    @progNum++
                    @statusCallback @progNum, @progDenom
                    @tweetCallback tweet
                    @processConversation()
        else
            @doneCallback()


    getMoreConversation: (user, tweetId, max_position) ->
        url = "/i/#{user}/conversation/#{tweetId}?include_available_features=1&include_entities=1&max_position=#{max_position}"
        d3.json(url)
            .header('x-push-state-request', 'true')
            .get (error, data) =>
                parser = new window.DOMParser()
                doc = parser.parseFromString data.items_html, 'text/html'
                tweetQueue = @tweetQueue
                i = 0

                d3.select(doc).selectAll('.simple-tweet').each ->
                    replyDiv = d3.select this
                    replyId = replyDiv.attr 'data-tweet-id'
                    replyUser = replyDiv.attr 'data-screen-name'
                    tweetQueue.push [replyId, replyUser]
                    max_position = replyId
                    i++

                @progDenom += i
                @statusCallback 0, @progDenom
                if data.has_more_items
                    @getMoreConversation(user, tweetId, max_position)
                else
                    @processConversation()


    getConversation: (user, tweetId) ->
        @tweetQueue.push([tweetId, user])
        @getMoreConversation user, tweetId, 0



class TweetVis
    margin: 100

    init: =>
        @makeSVG()

    makeSVG: =>
        d3.select('#tweetvis').remove()
        container = d3.select('body')

        d3.select(window).on('popstate',
            -> d3.select('#tweetvis').remove())

        @div = container.append('div')
            .attr('id', 'tweetvis')
            .style('position', 'fixed')
            .style('left', 0)
            .style('top', 0)
            .style('bottom', 0)
            .style('right', 0)
            .style('z-index', 1001)
            .style('background-color', '#222')

        @div.append('p')
            .style('position', 'absolute')
            .style('bottom', '20px')
            .style('left', '20px')
            .style('color', '#ddd')
            .html('''
            Visualization by <a target="_blank" href="http://paulbutler.org">Paul Butler</a>
            (<a target="_blank" href="https://twitter.com/paulgb">@paulgb</a>)
            Made with <a target="_blank" href="http://d3js.org/">d3</a>.
            <a target="_blank" href="https://github.com/paulgb/tweetvis">Source</a>
            ''')

        clog @div.append('p').selectAll('span')
        @div.append('p')
            .text('Reply times: ')
            .style('position', 'absolute')
            .style('top', '20px')
            .style('left', '20px')
            .style('color', '#ddd')
            .selectAll('span')
            .data(d3.zip(timeColors.humanIntervals, timeColors.colors))
            .enter()
            .append('span')
                .text((d) -> d[0] + ' ')
                .style('color', (d) -> d[1])
                .style('margin-left', '20px')

        @svg = @div.append('svg:svg')
        @svg.attr('id', 'tweetvis_svg')
            .attr('height', '100%')
            .attr('width', '100%')
            
        @svg.append('g')
            .attr('id', 'edges')

        @svg.append('g')
            .attr('id', 'nodes')

        @svg.append('g')
            .attr('id', 'details')


    makeLayout: (root, @maxWidth, @depth) =>
        tree = d3.layout.tree().size([1, 1])
        @layout = tree.nodes(root)
        @links = tree.links(@layout)
        @drawTree()


    drawTree: =>
        width = window.innerWidth
        height = window.innerHeight
        margin = 60
        nodeSize = 24
        scale = 8 / Math.min(Math.max(8, @maxWidth, @depth), 24)
        animDuration = 300

        x = d3.scale.linear().range([margin, width - 2*margin])
        y = d3.scale.linear().range([margin, height - 2*margin])

        cs = d3.scale.sqrt()
            .domain(timeColors.intervals)
            .range(timeColors.colors)

        ###
        #   Draw Nodes
        ###

        nodeGroup = d3.select('svg #nodes').selectAll('g')
           .data(@layout, (d) -> d.id)

        nodeGroup.transition()
            .duration(animDuration)
            .attr('transform', (d) -> "translate(#{x(d.x)} #{y(d.y)}) scale(#{scale})")
            .attr('x', (d) -> x(d.x))
            .attr('y', (d) -> y(d.y))

        enterNodes = nodeGroup.enter().append('g')
                .attr('transform', (d) -> "translate(#{x(d.x)} #{y(d.y)}) scale(#{scale})")
                .on('mouseover', tooltip)
                .attr('x', (d) -> x(d.x))
                .attr('y', (d) -> y(d.y))

        enterNodes.append('image')
                .attr('xlink:href', (d) -> d.avatar)
                .attr('height', "#{nodeSize}px")
                .attr('width', "#{nodeSize}px")
                .attr('x', "-#{nodeSize/2}px")
                .attr('y', "-#{nodeSize/2}px")
                .attr('opacity', 0)
                .transition().delay(animDuration)
                .attr('opacity', 1)

        enterNodes.append('rect')
                .attr('height', "#{nodeSize}px")
                .attr('width', "#{nodeSize}px")
                .attr('x', "-#{nodeSize/2}px")
                .attr('y', "-#{nodeSize/2}px")
                .attr('stroke', 'white')
                .attr('stroke-width', '2px')
                .attr('rx', "2px")
                .attr('fill', 'none')
                .attr('opacity', 0)
                .transition().delay(animDuration)
                .attr('opacity', 1)

        ###
        #   Draw Edges
        ###

        edgeToPath = ({source, target}) =>
            startX = x(source.x)
            startY = y(source.y)
            endX = x(target.x)
            endY = y(target.y)
            "M#{startX},#{startY} C#{startX},#{startY} #{endX},#{startY} #{endX},#{endY}"

        pathGroup = @svg.select('#edges').selectAll('path')
           .data(@links, (d) -> d.target.id)

        pathGroup
            .transition().duration(animDuration)
            .attr('d', edgeToPath)
            .attr('opacity', 1)

        pathGroup
           .enter()
                .append('path')
                .attr('d', edgeToPath)
                .attr('fill', 'none')
                .attr('stroke', (d) -> cs(d.target.time - d.source.time))
                .attr('stroke-width', '2px')
                .attr('opacity', 0)
                .transition().delay(animDuration)
                .attr('opacity', 1)


tweetLoader = new TweetLoader()


if not tweetLoader.testTweet()
    alert 'Not on a tweet; Navigate to a tweet and try again'

else
    tweetVis = new TweetVis()
    tweetVis.init()

    loadingIndicator = new LoadingIndicator(tweetVis.div)

    treeBuilder = new TreeBuilder()
    treeBuilder.changeCallback = tweetVis.makeLayout

    window.onresize = tweetVis.drawTree
    tweetLoader.tweetCallback = treeBuilder.addNode
    tweetLoader.statusCallback = loadingIndicator.updateProgress
    tweetLoader.doneCallback = loadingIndicator.done
    tweetLoader.getTweetTree()

