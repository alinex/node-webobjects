
# Main controlling class
# =================================================



# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug') 'webobjects'
debugAccess = require('debug') 'webobjects:access'
chalk = require 'chalk'
path = require 'path'
async = require 'async'
fs = require 'fs'
util = require 'alinex-util'
# express
express = require 'express'
helmet = require 'helmet'
compression = require 'compression'
# include alinex modules
config = require 'alinex-config'
Database = require 'alinex-database'
Exec = require 'alinex-exec'
ssh = require 'alinex-ssh'
# internal methods
schema = require './configSchema'


# Initialize
# -------------------------------------------------
exports.setup = (cb) ->
  async.each [ssh, Exec, Database], (mod, cb) ->
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
  # output version header
  app.get '/', (req, res, next) ->
    fs.readFile "#{__dirname}/../package.json", 'utf8', (err, contents) ->
      return next err if err
      pack = JSON.parse contents
      res.send "Alinex WebObjects Version #{pack.version}"
  # access object by identification
  app.get '/:group/:class/:id', (req, res) ->
    def = config.get "/webobjects/#{req.params.group}/#{req.params.class}"
    debugAccess "#{req.params.group}/#{req.params.class}/#{req.params.id}"
    html = "<h1>#{def.title}: #{def.id}=#{req.params.id}</h1>"
    html += "<p>#{def.description}</p>" if def.description
    html += "<h3>Definition:</h3><pre>#{util.inspect def}</pre>"
    data = Database.record def.database.connection, def.database.get, req.params.id, (err, record) ->
      html += "<h3>Data:</h3><pre>#{util.inspect err ? record}</pre>"
      res.send html
  # Failure processing
  app.use logErrors
  app.use clientErrorHandler
  app.use errorHandler
  # start
  server = config.get '/server/http'
  app.listen server.port, ->
    console.log "Example app listening on port #{server.port}!"
    cb()

  Database.instance 'dvb_manage_live', (err, conn) ->
    throw err if err
    console.log "STEP 1 OK"
    data = Database.record 'dvb_manage_live', "SELECT count(*) from mng_media_version", (err, record) ->
      throw err if err
      console.log "STEP 2 OK"


# Helper Middleware
# ---------------------------------------

logErrors = (err, req, res, next) ->
  console.error err.stack
  next err

clientErrorHandler = (err, req, res, next) ->
  next err unless req.xhr
  res.status 500
  .send {error: err.message}

errorHandler = (err, req, res, next) ->
  res.status 500
  .render 'error', {error: err}
