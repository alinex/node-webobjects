# Main controlling class
# =================================================


# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug') 'webobjects'
chalk = require 'chalk'
path = require 'path'
async = require 'async'
# express
express = require 'express'
helmet = require 'helmet'
compression = require 'compression'
# include alinex modules
config = require 'alinex-config'
Database = require 'alinex-database'
Exec = require 'alinex-exec'
# internal methods
schema = require './configSchema'


# Initialize
# -------------------------------------------------
exports.setup = (cb) ->
  async.each [Exec, Database], (mod, cb) ->
    mod.setup cb
  , (err) ->
    return cb err if err
    # add schema for module's configuration
    config.setSchema '/server', schema.server
    config.setSchema '/webobjects', schema.webobjects
    # set module search path
    config.register 'webobjects', path.dirname __dirname
    cb()

exports.start = (cb = ->) ->
  # configure web server
  app = express()
  app.use helmet()
  app.use compression()
  # configure routing
  app.get '/', (req, res) -> res.send 'Hello World!'
  # Failure processing
  app.use logErrors
  app.use clientErrorHandler
  app.use errorHandler
  # start
  server = config.get '/server/http'
  app.listen server.port, ->
    console.log "Example app listening on port #{server.port}!"
    cb()


# Helper Middleware
# ---------------------------------------

logErrors = (err, req, res, next) ->
  console.error err.stack
  next err

clientErrorHandler = (err, req, res, next) ->
  next err unless req.xhr
  res.status 500
  .send {error: 'Something failed!'}

errorHandler = (err, req, res, next) ->
  res.status 500
  .render 'error', {error: err}
