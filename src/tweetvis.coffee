
d3 = require 'd3'

# twitter disables the console, but it's useful
window.console.log = console.__proto__.log

class TweetVis
    margin: 100

    getTweetTree: =>
        tweets = d3.selectAll('.tweet')

        root = null
        last_tweet = {}
        i = 0

        tweets.each ->
            tweet = {}
            elem = d3.select this
            #console.log this
            tweet.id = elem.attr 'data-tweet-id'
            tweet.user = elem.attr 'data-screen-name'
            tweet.content = elem.select('.tweet-text').text()
            tweet.index = i
            tweet.mentions = (elem.attr 'data-mentions').split ' '
            tweet.children = []
            console.log tweet

            parent = null
            for mention in tweet.mentions
                if mention not of last_tweet
                    continue
                else if parent is null
                    parent = last_tweet[mention]
                else if last_tweet[mention].index > parent.index
                    parent = last_tweet[mention]

            if i == 0
                root = tweet
            else
                parent.children.push tweet

            ++i
            last_tweet[tweet.user] = tweet
        @root = root


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
            
        @svg.append('rect')
            .attr('x', -2500)
            .attr('y', -2500)
            .attr('width', 5000)
            .attr('height', 5000)
            .style('fill', 'white')


    treeLayout: =>
        tree = d3.layout.tree().size([@width - 2*@margin, @height - 2*@margin])
        @layout = tree.nodes(@root)
        @links = tree.links(@layout)


    drawTree: =>
        nodeGroup = @svg.selectAll('.node')
           .data(@layout)
           .enter()
                .append('g')

        nodeGroup.append('title')
            .text((d) -> d.content)

        nodeGroup.append('circle')
                .attr('cx', (d) => d.x + @margin)
                .attr('cy', (d) => d.y + @margin)
                .attr('r', 5)

        edgeToPath = ({source, target}) =>
            d3.svg.line().x((d) => d.x + @margin)
                         .y((d) => d.y + @margin)
                         .interpolate('linear')([source, target])

        @svg.selectAll('.path')
           .data(@links)
           .enter()
                .append('path')
                .attr('d', (x) -> edgeToPath(x))
                .attr('stroke', 'blue')
        

    main: =>
        @makeSVG()
        @getTweetTree()
        @treeLayout()
        @drawTree()


(new TweetVis()).main()

