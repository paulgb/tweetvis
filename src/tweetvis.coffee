
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
            clog url
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
                    tweet.text = tweetDiv.select('.tweet-text').text()
                    tweet.avatar = tweetDiv.select('.avatar').attr('src')

                    #clog tweet
                    @tweetCallback tweet
                    @processConversation()


    getMoreConversation: (user, tweetId, max_position) ->
        url = "/i/#{user}/conversation/#{tweetId}?include_available_features=1&include_entities=1&max_position=#{max_position}"
        d3.json(url)
            .header('x-push-state-request', 'true')
            .get (error, data) =>
                parser = new window.DOMParser()
                doc = parser.parseFromString data.items_html, 'text/html'
                tweetQueue = @tweetQueue

                d3.select(doc).selectAll('.simple-tweet').each ->
                    replyDiv = d3.select this
                    replyId = replyDiv.attr 'data-tweet-id'
                    replyUser = replyDiv.attr 'data-screen-name'
                    tweetQueue.push [replyId, replyUser]
                    max_position = replyId

                if data.has_more_items
                    clog 'more'
                    @getMoreConversation(user, tweetId, max_position)
                else
                    clog 'done'
                    @processConversation()


    getConversation: (user, tweetId) ->
        @tweetQueue.push([tweetId, user])
        @getMoreConversation user, tweetId, 0




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

