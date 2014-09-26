
d3 = require 'd3'

window.d3 = d3

# twitter disables the console, but it's useful
clog = (m) ->
    console.__proto__.log.call(console, m)

backdrop = (elems) ->
    elems.each ->
        elem = d3.select this
        {height, width} = elem.node().getBBox()
        p = d3.select(elem.node().parentNode)
        p.insert('rect', ':first-child')
            .classed('hoverReveal', true)
            .attr('width', width + 12)
            .attr('height', height + 12)
            .attr('x', -6)
            .attr('y', -6)
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
    dy = 1.1
    tspan = text.text(null)
                .append("tspan")
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
                        .attr("x", '0px')
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
                    tweet.content = tweetDiv.select('.tweet-text').text()
                    tweet.avatar = tweetDiv.select('.avatar').attr('src')

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
        d3.select('#tweetvis').remove()
        container = d3.select('body')

        div = container.append('div')
            .attr('id', 'tweetvis')
            .style('position', 'fixed')
            .style('left', 0)
            .style('top', 0)
            .style('bottom', 0)
            .style('right', 0)
            .style('z-index', 1001)
            .style('background-color', 'white')

        @svg = div.append('svg:svg')
        @svg.attr('id', 'tweetvis_svg')
            .attr('height', '100%')
            .attr('width', '100%')
            
        @svg.append('style')
            .text('''
            
            #details rect.hoverCapture {
                opacity: 0;
            }

            #details g .hoverReveal {
                opacity: 0;
            }

            #details g:hover .hoverReveal {
                opacity: 0.9;
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


    makeLayout: (root) =>
        #tree = d3.layout.tree().size([@width - 2*@margin, @height - 2*@margin])
        tree = d3.layout.tree().size([1, 1])
        @layout = tree.nodes(root)
        @links = tree.links(@layout)
        @drawTree()


    drawTree: =>
        width = window.innerWidth
        height = window.innerHeight
        margin = 60
        nodeSize = 24

        x = d3.scale.linear().range([margin, width - 2*margin])
        y = d3.scale.linear().range([margin, height - 2*margin])

        ###
        #   Draw Nodes
        ###

        nodeGroup = d3.select('svg #nodes').selectAll('g')
           .data(@layout, (d) -> d.id)
        nodeGroup.attr('transform', (d) -> "translate(#{x(d.x)} #{y(d.y)})")

        enterNodes = nodeGroup.enter().append('g')
                .attr('transform', (d) -> "translate(#{x(d.x)} #{y(d.y)})")

        enterNodes.append('image')
                .attr('xlink:href', (d) -> d.avatar)
                .attr('height', "#{nodeSize}px")
                .attr('width', "#{nodeSize}px")
                .attr('x', "-#{nodeSize/2}px")
                .attr('y', "-#{nodeSize/2}px")


        enterNodes.append('rect')
                .attr('height', "#{nodeSize}px")
                .attr('width', "#{nodeSize}px")
                .attr('x', "-#{nodeSize/2}px")
                .attr('y', "-#{nodeSize/2}px")
                .attr('stroke', 'white')
                .attr('stroke-width', '2px')
                .attr('rx', "2px")
                .attr('fill', 'none')

        ###
        #   Draw Edges
        ###

        edgeToPath = ({source, target}) =>
            d3.svg.line().x((d) => x(d.x))
                         .y((d) => y(d.y))
                         .interpolate('linear')([source, target])

        pathGroup = @svg.select('#edges').selectAll('path')
           .data(@links, (d) -> d.target.id)

        pathGroup
            .attr('d', (x) -> edgeToPath(x))

        pathGroup
           .enter()
                .append('path')
                .attr('d', (x) -> edgeToPath(x))
                .attr('stroke', 'white')
                .attr('stroke-width', '4px')

        ###
        #   Draw (Hidden) Details Containers
        ###
        
        detailsGroup = @svg.select('#details').selectAll('g')
            .data(@layout, (d) -> d.id)

        detailsEnter = detailsGroup.enter().append('g')
        
        detailsEnter.append('g').attr('transform', 'translate(24 24)').append('text')
            .classed('hoverReveal', true)
            .text((d) -> d.content)
            .call(wrap, 300)
            .call(backdrop)

        detailsEnter.append('rect')
            .classed('hoverCapture', true)
            .attr('x', "-#{nodeSize/2}px")
            .attr('y', "-#{nodeSize/2}px")
            .attr('height', "#{nodeSize}px")
            .attr('width', "#{nodeSize}px")
            .attr('stroke', 'white')
            .attr('stroke-width', '4px')
            .attr('rx', 5)
            .attr('fill', 'white')

        detailsGroup.attr('transform', (d) -> "translate(#{x(d.x)} #{y(d.y)})")
           
        

tweetVis = new TweetVis()
tweetVis.init()

treeBuilder = new TreeBuilder()
treeBuilder.changeCallback = tweetVis.makeLayout

window.onresize = tweetVis.drawTree

tweetLoader = new TweetLoader()
tweetLoader.tweetCallback = treeBuilder.addNode
tweetLoader.getTweetTree()

