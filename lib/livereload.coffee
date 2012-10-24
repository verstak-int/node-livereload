fs   = require 'fs'
path = require 'path'
ws   = require 'websocket.io'
http  = require 'http'
express  = require 'express'
url = require 'url'
watchr = require('watchr')

version ='7'
defaultPort = 35729

defaultExts = [
  'html', 'css', 'js', 'png', 'gif', 'jpg',
  'php', 'php5', 'py', 'rb', 'erb', 'jade'
]

defaultAlias =
  'styl': 'css'

defaultExclusions = ['.git/', '.svn/', '.hg/']

merge = (obj1, obj2) ->
  _obj = {}
  _obj[key] = value for key, value of obj1
  _obj[key] = value for key, value of obj2
  _obj

class Server
  constructor: (@config) ->
    @config ?= {}

    @config.version ?= version
    @config.port    ?= defaultPort

    @config.exts       ?= []
    @config.exclusions ?= []
    @config.alias      ?= {}

    @config.exts       = @config.exts.concat defaultExts
    @config.exclusions = @config.exclusions.concat defaultExclusions
    @config.alias      = merge( defaultAlias, @config.alias )

    @config.applyJSLive  ?= false
    @config.applyCSSLive ?= true

    @sockets = []
    
  listen: ->
    @debug "LiveReload is waiting for browser to connect."
    
    if @config.server
      @config.server.listen @config.port
      @server = ws.attach(@config.server)
    else
      @server = ws.listen(@config.port)

    @server.on 'connection', @onConnection.bind @
    @server.on 'close',      @onClose.bind @


  onConnection: (socket) ->
    @debug "Browser connected."
    
    socket.send JSON.stringify 
      command: 'hello',
      protocols: [
        'http://livereload.com/protocols/official-7'
      ]
      serverName: 'node-livereload'

    socket.on 'message', (message) =>
      @debug "Browser URL: #{message}"

    @sockets.push socket
    
  onClose: (socket) ->
    @debug "Browser disconnected."
  
  watch: (source)=>

    # Watch a directory or file
    exts       = @config.exts
    exclusions = @config.exclusions

    watchr.watch
      path: source
      ignoreHiddenFiles: yes
      listener: (eventName, filePath, fileCurrentStat, filePreviousStat)=>

        for exclusion in exclusions
          return if filePath.match exclusion
        
        for ext in exts when filePath.match "\.#{ext}$"
          setTimeout =>
            @reloadFile(filePath)
          , 50
    
  reloadFile: (filepath) ->
    @debug "Reload file: #{filepath}"
    ext       = path.extname(filepath).substr(1)
    aliasExt  = @config.alias[ext]
    if aliasExt?
      @debug "and aliased to #{aliasExt}"
      filepath = filepath.replace("." + ext, ".#{aliasExt}")
      
    data = JSON.stringify 
      command: 'reload',
      path: filepath,
      liveJS: @config.applyJSLive,
      liveCSS: @config.applyCSSLive

    for socket in @sockets
      socket.send data
    
  reloadAll: -> 
    @debug "Reload all"
    data = JSON.stringify 
      command: 'reload',
      path: '*'
      liveJS: false,
      liveCSS: false
    
    for socket in @sockets
      socket.send data

  debug: (str) ->
    if @config.debug
      console.log "#{str}\n"
      
exports.createServer = (config = {}) ->
  server = new Server config

  unless config.server?
    app = express()
    app.use express.static "#{__dirname}/../ext"
    app.get '/livereload.js', (req, res) ->
      res.sendfile "#{__dirname}/../ext/livereload.js"
    app.post '/reload', (req, res) -> 
      do server.reloadAll
      res.send ""
    config.server = http.createServer app

  server.listen()
  server

