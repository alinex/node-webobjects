
# Main controlling class
# =================================================



# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug') 'webobjects:access'
chalk = require 'chalk'
path = require 'path'
async = require 'async'
fs = require 'fs'
# express
express = require 'express'
helmet = require 'helmet'
compression = require 'compression'
basicAuth = require 'basic-auth'
crypto = require 'crypto'
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
  app.enable 'trust proxy'
  # basic authentication
  app.all "/*", (req, res, next) ->
    user = basicAuth req
    if not(user?.name) or not(user?.pass)
      res.set 'WWW-Authenticate', 'Basic realm=Authorization Required'
      res.sendStatus 401
      return
    passmd5 = crypto.createHash('md5').update(user.pass).digest('hex')
    if config.get("/webobjects/auth/#{user.name}") is passmd5
      req.user = user
      next()
    else
      debug chalk.magenta "WARN Wrong User Authentication for #{user.name} with #{user.pass}"
      res.set 'WWW-Authenticate', 'Basic realm=Authorization Required'
      res.sendStatus 401
  # output version header
  app.get '/', (req, res, next) ->
    fs.readFile "#{__dirname}/../package.json", 'utf8', (err, contents) ->
      return next err if err
      pack = JSON.parse contents
      setup = config.get "/webobjects"
      debug "INFO /", chalk.grey "(by #{req.user.name})"
      report = new Report()
      report.h1 "Alinex WebObjects Version #{pack.version}"
      report.markdown pack.description
      report.markdown """
      This tool won't replace any querying tool like SQL applications... But it will
      give you an alternative way to step through your data and discover things on
      an interactive way through the data jungle.
      """
      if setup.favorites
        # favorite access
        report.h3 'Favorites'
        table = []
        for fav in setup.favorites
          if typeof fav is 'string'
            [group, object, search] = fav.split '/'
          else
            key = Object.keys(fav)[0]
            [group, object] = key.split '/'
            search = fav[key]
          search = [search] unless Array.isArray search
          form = search.map (e) ->
            "#{e}=<!-- @html <form action=\"/#{group}/#{object}/#{e}?\">
            <input type=\"text\" name=\"values\"></input>
            </form> -->"
          .join ' '
          table.push [group, object, form]
        report.table table, ["Group", 'Objects', 'Access'], null, true
      # complete index
      report.h3 'Complete Index'
      table = []
      for search, conf of setup.object
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
    setup = config.get "/webobjects/object/#{req.params.group}"
    debug "INFO /#{req.params.group}", chalk.grey "(by #{req.user.name})"
    report = new Report()
    report.h1 "Group: #{req.params.group}"
    unless setup
      debug chalk.magenta "unknown group #{req.params.group}"
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
  app.get '/:group/:object', (req, res) ->
    setup = config.get "/webobjects/object/#{req.params.group}/#{req.params.object}"
    debug "INFO /#{req.params.group}/#{req.params.object}", chalk.grey "(by #{req.user.name})"
    report = new Report()
    unless setup
      debug chalk.magenta "Unknown object #{req.params.group}/#{req.params.object}"
      report.h1 "Object: #{req.params.group}/#{req.params.object}"
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
          "`/#{req.params.group}/#{req.params.object}/#{search}/...`"
          conf.params.title
          "[Information](/#{req.params.group}/#{req.params.object}/#{search})"
        ]
      report.table table, ["Access method", 'URL', 'Parameter', 'Info'], null, true
    report.format 'html', (err, html) ->
      res.send html

  # access object by identification
  app.get '/:group/:object/:search', (req, res) ->
    if req.query?.values
      return res.redirect 301, "/#{req.params.group}/#{req.params.object}/#{req.params.search}\
      /#{encodeURI req.query.values}"
    setup = config.get "/webobjects/object/#{req.params.group}/#{req.params.object}"
    debug "INFO /#{req.params.group}/#{req.params.object}/#{req.params.search}",
    chalk.grey "(by #{req.user.name})"
    report = new Report()
    unless setup
      debug chalk.magenta "Unknown object #{req.params.group}/#{req.params.object}"
      report.h1 "Object: #{req.params.group}/#{req.params.object}"
      report.box "This object is not defined!", 'alert'
      report.markdown "See the [list of objects](/#{req.params.group}) in #{req.params.group}
      or the [list of groups](/) to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    unless setup.get?[req.params.search]
      debug chalk.magenta "Unknown search method #{req.params.group}/#{req.params.object}\
      /#{req.params.search}"
      report.h1 "#{setup.title}: Access by #{req.params.search}"
      report.box "This search method is not defined!", 'alert'
      report.markdown "See the [list of methods](/#{req.params.group}/#{req.params.object})
      to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    report.h1 "#{setup.title}: #{setup.get[req.params.search].title}"
    if setup.get[req.params.search].description
      report.markdown setup.get[req.params.search].description
    report.box true, 'info'
    report.raw """
      <form action="?">
      <p>URL: /#{req.params.group}/#{req.params.object}/#{req.params.search}/
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
    setup = config.get "/webobjects/object/#{req.params.group}/#{req.params.object}"
    debug "GET  /#{req.params.group}/#{req.params.object}/#{req.params.search}/\
    #{req.params.values}", chalk.grey "(by #{req.user.name})"
    report = new Report()
    unless setup
      debug chalk.magenta "Unknown object #{req.params.group}/#{req.params.object}"
      report.h1 "Object: #{req.params.group}/#{req.params.object}"
      report.box "This object is not defined!", 'alert'
      report.markdown "See the [list of objects](/#{req.params.group}) in #{req.params.group}
      or the [list of groups](/) to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    unless setup.get?[req.params.search]
      debug chalk.magenta "Unknown search method #{req.params.group}/#{req.params.object}\
      /#{req.params.search}"
      report.h1 "#{setup.title}: Access by #{req.params.search}"
      report.box "This search method is not defined!", 'alert'
      report.markdown "See the [list of methods](/#{req.params.group}/#{req.params.object})
      to use the correct one."
      return report.format 'html', (err, html) -> res.send html
    if setup.get.access
      access = config.get "/webobjects/access/#{setup.get.access}"
      ipFailed = access.ip and req.ip not in access.ip
      userFailed = access.user and req.user.name not in access.user
      if ipFailed or userFailed
        report.h1 "#{setup.title}: Access Restricted to '#{setup.get.access}'"
        report.box "You are not allowed to access here!\nUser: #{req.user.name} from #{req.ip}",
        'alert'
        report.markdown "See the [list of objects](/#{req.params.group})
        to use another one."
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
        debug chalk.red "GET  #{req.params.group}/#{req.params.object} -> #{err.message}"
        return
      report.markdown setup.description if setup.description
      if worker.code
        report.hr()
        report.p "The result was retrieved using:"
        report.box true, 'info', worker.code.title
        report.code worker.code.data, worker.code.language
        report.box false
      report.format 'html', (err, html) ->
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
