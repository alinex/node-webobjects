
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
Worker = require './worker'


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
      report.markdown pack.description
      report.markdown """
      This tool won't replace any querying tool like SQL applications... But it will
      give you an alternative way to step through your data and discover things on
      an interactive way through the data jungle.
      """
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
    if req.params.group in ['favicon.ico', 'robots.txt']
      res.status 404
      .send {error: "No file available!"}
      return
    setup = config.get "/webobjects/#{req.params.group}"
    debugAccess "INFO #{req.params.group}"
    report = new Report()
    report.h1 "Group: #{req.params.group}"
    unless setup
      debugAccess chalk.magenta "unknown group #{req.params.group}"
      report.box "This group is not defined!", 'alert'
      report.markdown "See the [list of groups](/) to use the correct one."
    else
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
    unless setup
      debugAccess chalk.magenta "Unknown object #{req.params.group}/#{req.params.class}"
      report.h1 "Object: #{req.params.group}/#{req.params.class}"
      report.box "This object is not defined!", 'alert'
      report.markdown "See the [list of objects](/#{req.params.group}) in #{req.params.group}
      or the [list of groups](/) to use the correct one."
    else
      report.h1 "#{setup.title}"
      report.markdown setup.description if setup.description
      table = []
      for search, conf of setup.get
        table.push [
          "**#{conf.title}**"
          "`/#{req.params.group}/#{req.params.class}/#{search}/...`"
          conf.params.title
          "[Information](/#{req.params.group}/#{req.params.class}/#{search})"
        ]
      report.table table, ["Access method", 'URL', 'Parameter', 'Info'], null, true
    report.format 'html', (err, html) ->
      res.send html

  # access object by identification
  app.get '/:group/:class/:search', (req, res) ->
    if req.query?.values
      console.log encodeURI req.query.values
      return res.redirect 301, "/#{req.params.group}/#{req.params.class}/#{req.params.search}\
      /#{encodeURI req.query.values}"
    setup = config.get "/webobjects/#{req.params.group}/#{req.params.class}"
    debugAccess "INFO #{req.params.group}/#{req.params.class}/#{req.params.search}"
    report = new Report()
    unless setup
      debugAccess chalk.magenta "Unknown object #{req.params.group}/#{req.params.class}"
      report.h1 "Object: #{req.params.group}/#{req.params.class}"
      report.box "This object is not defined!", 'alert'
      report.markdown "See the [list of objects](/#{req.params.group}) in #{req.params.group}
      or the [list of groups](/) to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    unless setup.get?[req.params.search]
      debugAccess chalk.magenta "Unknown search method #{req.params.group}/#{req.params.class}\
      /#{req.params.search}"
      report.h1 "#{setup.title}: Access by #{req.params.search}"
      report.box "This search method is not defined!", 'alert'
      report.markdown "See the [list of methods](/#{req.params.group}/#{req.params.class})
      to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    report.h1 "#{setup.title}: #{setup.get[req.params.search].title}"
    report.markdown setup.get[req.params.search].description if setup.get[req.params.search].description
    report.box true, 'info'
    report.raw """
      <form action="?">
      <p>URL: /#{req.params.group}/#{req.params.class}/#{req.params.search}/
      <input type="text" name="values"></input>
      </form>
      """, 'html'
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
    report = new Report()
    unless setup
      debugAccess chalk.magenta "Unknown object #{req.params.group}/#{req.params.class}"
      report.h1 "Object: #{req.params.group}/#{req.params.class}"
      report.box "This object is not defined!", 'alert'
      report.markdown "See the [list of objects](/#{req.params.group}) in #{req.params.group}
      or the [list of groups](/) to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    unless setup.get?[req.params.search]
      debugAccess chalk.magenta "Unknown search method #{req.params.group}/#{req.params.class}\
      /#{req.params.search}"
      report.h1 "#{setup.title}: Access by #{req.params.search}"
      report.box "This search method is not defined!", 'alert'
      report.markdown "See the [list of methods](/#{req.params.group}/#{req.params.class})
      to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    worker = new Worker
      setup: setup
      group: req.params.group
      object: req.params.object
      search: req.params.search
      values: req.params.values
      report: report
    report.h1 setup.title
    report.markdown "> Search for: #{setup.get[req.params.search].title}
    using `#{req.params.values}`"
    async.series [
      (cb) -> worker.read cb
      (cb) -> worker.format cb
      (cb) -> worker.reference cb
      (cb) -> worker.output cb
    ], (err) ->
      if err
        report = new Report()
        report.h1 "#{setup.title}: Access Failure"
        report.box true, 'alert'
        report.markdown err.message
        report.box false
        report.pre err.stack
        report.format 'html', (err, html) -> res.send html
        debugAccess chalk.red "GET  #{req.params.group}/#{req.params.class} -> #{err.message}"
        return
      report.markdown setup.description if setup.description
      if worker.code
        report.hr()
        report.p "The result was retrieved using:"
        report.box true, 'info', worker.code.title
        report.code worker.code.data, worker.code.language
        report.box false
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
