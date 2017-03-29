
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
  async.each [ssh, Exec, Database, Report], (mod, cb) ->
    mod.setup cb
  , (err) ->
    return cb err if err
    # add schema for module's configuration
    config.setSchema '/server', schema.server
    config.setSchema '/webobjects', schema.webobjects
    # set module search path
    config.register 'webobjects', path.dirname __dirname
    config.register false, path.dirname(__dirname),
      folder: 'template'
      type: 'template'
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
      setup = config.get "/webobjects"
      debugAccess "INFO /"
      report = new Report()
      report.h1 "Alinex WebObjects Version #{pack.version}"
      report.p pack.description
      table = []
      for search, conf of setup
        table.push [
          "**#{search}**"
          Object.keys(conf).length
          "`/#{search}`"
          "[Information](/#{search})"
        ]
      report.table table, ["Group", 'Objects', 'URL', 'Action'], null, true
      report.format 'html', (err, html) ->
        res.send html

  # group information
  app.get '/:group', (req, res) ->
    setup = config.get "/webobjects/#{req.params.group}"
    debugAccess "INFO #{req.params.group}"
    report = new Report()
    report.h1 "Group: #{req.params.group}"
    table = []
    for search, conf of setup
      table.push [
        "**#{conf.title}**"
        conf.type
        "`/#{req.params.group}/#{search}`"
        "[Information](/#{req.params.group}/#{search})"
      ]
    report.table table, ["Object", 'Resource', 'URL', 'Action'], null, true
    report.format 'html', (err, html) ->
      res.send html

  # class information
  app.get '/:group/:class', (req, res) ->
    setup = config.get "/webobjects/#{req.params.group}/#{req.params.class}"
    debugAccess "INFO #{req.params.group}/#{req.params.class}"
    report = new Report()
    report.h1 "#{setup.title}"
    report.p setup.description if setup.description
    table = []
    for search, conf of setup.get
      table.push [
        "**#{conf.title}**"
        "`/#{req.params.group}/#{req.params.class}/#{search}/...`"
        conf.params.title
        "[Information](/#{req.params.group}/#{req.params.class}/#{search})"
      ]
    report.table table, ["Access method", 'URL', 'Parameter', 'Action'], null, true
    report.format 'html', (err, html) ->
      res.send html

  # access object by identification
  app.get '/:group/:class/:search', (req, res) ->
    setup = config.get "/webobjects/#{req.params.group}/#{req.params.class}"
    debugAccess "INFO #{req.params.group}/#{req.params.class}/#{req.params.search}"
    report = new Report()
    report.h1 "#{setup.title}: #{setup.get[req.params.search].title}"
    report.p setup.get[req.params.search].description if setup.get[req.params.search].description
    report.box true, 'info'
    report.p true
    report.text "URL: /#{req.params.group}/#{req.params.class}/#{req.params.search}/..."
    report.box false
    report.h3 'Parameter:'
    validator.describe
      name: 'params'
      schema: setup.get[req.params.search].params
    , (_, text) ->
      report.markdown text
      report.format 'html', (err, html) ->
        res.send html

  # access object searches
  app.get '/:group/:object/:search/:values', (req, res) ->
    setup = config.get "/webobjects/#{req.params.group}/#{req.params.object}"
    debugAccess "GET  #{req.params.group}/#{req.params.object}/#{req.params.search}
    = #{req.params.values}"
    work =
      group: req.params.group
      object: req.params.object
      search: req.params.search
      values: req.params.values
      result: null # list or record
      data: null # dataset
    try
      async.series [
        (cb) -> provider.read setup, work, cb
        (cb) -> provider.format setup, work, cb
        (cb) -> provider.reference setup, work, cb
        (cb) -> provider.flip setup, work, cb
      ], (err) ->
        throw err if err
        report = new Report()
        report.h1 "#{setup.title}: #{setup.get[work.search].title}"
        report.p setup.description if setup.description
        if work.data.data.length > 1
          report.table work.data, true
        else
          report.box true, 'warning'
          report.h3 'No records found!'
          report.box false
          report.p "You may correct your query parameters in the path."
        report.format 'html', (err, html) -> res.send html
    catch error
      report = new Report()
      report.h1 "#{setup.title}: Access Failure"
      report.box true, 'alert'
      report.markdown error.message
      report.box false
      report.pre error.stack
      report.format 'html', (err, html) -> res.send html
      debugAccess chalk.red "GET  #{req.params.group}/#{req.params.class} -> #{error.message}"

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
  .send {error: err.message}

errorHandler = (err, req, res, next) ->
  res.status 500
  .render 'error', {error: err}
