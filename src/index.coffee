
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
Report = require 'alinex-report'
validator = require 'alinex-validator'
# internal methods
schema = require './configSchema'
provider = require './provider'


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

exports.init = (cb) ->
  config.init (err) ->
    throw err if err
    Report.init cb

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

  # class information
  app.get '/:group/:class', (req, res) ->
    def = config.get "/webobjects/#{req.params.group}/#{req.params.class}"
    debugAccess "INFO #{req.params.group}/#{req.params.class}"
    report = new Report()
    report.h1 "#{def.title}"
    report.p def.description if def.description
    report.pre util.inspect def, {depth: null}
    report.format 'html', (err, html) ->
      res.send html

  # access object by identification
  app.get '/:group/:class/:id', (req, res) ->
    def = config.get "/webobjects/#{req.params.group}/#{req.params.class}"
    debugAccess "GET #{req.params.group}/#{req.params.class}/#{req.params.id}"
    report = new Report()
    report.h1 "#{def.title}: #{def.id.title}=#{req.params.id}"
    report.p def.description if def.description
    validator.check
      name: 'id'
      value: req.params.id
      schema: def.id
    , (err, data) ->
      req.params.id = data
      if err
        debugAccess chalk.red "    failed with: #{err.message}"
        report.box err.message, 'alert'
        validator.describe
          name: 'id'
          schema: def.id
        , (err, text) ->
          report.markdown text
          report.format 'html', (err, html) ->
            res.send html
        return
      # execute
      Database.record def.database.connection, def.database.get, req.params.id.toString()
      , (err, record) ->
        if err
          debugAccess chalk.red "    failed with: #{err.message}"
          report.box err.message, 'alert'
        else unless record
          debugAccess chalk.yellow "    failed because no record found"
          report.box "No record found!", 'warning'
        else
          data = []
          for field, value of record
            continue unless value
            action = unless def.reference?[field] then null
            else
              "[#{def.reference[field]}](../#{def.reference?[field]}/#{value})"
            data.push [field, value, action]
          report.table data, ['Field', 'Value', 'Action'], null, true
          report.p "Fields with NULL values are not displayed!"
        report.format 'html', (err, html) ->
          res.send html

  # access object searches
  app.get '/:group/:object/:search/:values', (req, res) ->
    setup = config.get "/webobjects/#{req.params.group}/#{req.params.object}"
    debugAccess "GET #{req.params.group}/#{req.params.object}/#{req.params.search}
    = #{req.params.values}"
    work =
      search: req.params.search
      values: req.params.values
      result: null # list or record
      data: null # dataset
    try
      provider.read setup, work, (err) ->
        throw err if err
        # format
        # references
        # output
        report = new Report()
        report.h1 "#{setup.title}: #{setup.get[work.search].title}"
        report.p setup.description if setup.description
        report.table work.data, null, null, true
        report.format 'html', (err, html) -> res.send html
    catch error
      report = new Report()
      report.h1 "#{setup.title}: Access Failure"
      report.box true, 'alert'
      report.markdown error.message
      report.format 'html', (err, html) -> res.send html

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
    data = Database.record 'dvb_manage_live', "SELECT count(*) from mng_media_version"
    , (err, record) ->
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
