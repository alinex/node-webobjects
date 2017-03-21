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


# Initialize
# -------------------------------------------------
exports.setup = (cb) ->
  async.each [Exec, Database], (mod, cb) ->
    mod.setup cb
  , (err) ->
    return cb err if err
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
  app.listen 3000, ->
    console.log 'Example app listening on port 3000!'
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
