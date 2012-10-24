fs = require 'fs'

runner = ->

  livereload = require './livereload'
  resolve    = require('path').resolve
  opts       = require 'opts'

  opts.parse [
    {
      short: "p"
      long:  "port"
      description: "Specify the port"
      value: true
      required: false
    },
    {
      short: "c"
      long:  "config"
      description: "Specify the JSON config file"
      value: true
      required: false
    },
    {
      short: "d"
      long:  "delay"
      description: "Specify the wait delay (before refresh)."
      value: true
      required: false
    }
  ].reverse(), true

  config = {}
  if opts.get('config')?
    config = JSON.parse fs.readFileSync(opts.get('config'))

  config.port = opts.get('port') or config.port 
  config.delay = opts.get('delay') or config.delay

  config.debug ?= true

  server = livereload.createServer(config)

  path = resolve(opts.args()[0] or '.')

  console.log("Starting LiveReload on port #{server.config.port} for #{path}")
  
  server.watch(path)

module.exports =
  run: runner
