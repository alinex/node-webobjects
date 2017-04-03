
# Main controlling class
# =================================================
# The worker contains some context information like:
# - setup
# - group
# - object
# - search
# - values
# - report
# - code
# - result
# - data


# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug') 'webobjects:data'
chalk = require 'chalk'
# include alinex modules
Report = require 'alinex-report'
validator = require 'alinex-validator'


class Worker

  constructor: (data) ->
    @setup = data.setup
    @group = data.group
    @object = data.object
    @search = data.search
    @values = data.values
    @report = data.report ? new Report()

  read: (cb) ->
    # validate call
    if @search not in Object.keys @setup.get
      return cb new Error "Access type '#{@search}' is not defined."
    conf = @setup.get[@search]
    validator.check
      name: 'params'
      value: @values
      schema: conf.params
    , (err, res) ->
      @values = res
      if err
        debug chalk.red "    failed with: #{err.message}"
        validator.describe
          name: 'params'
          schema: conf.params
        , (_, text) ->
          cb new Error "### #{err.message}.\n\n#{text}"
        return
      # fetch data
      try
        provider = require "./provider/#{@setup.type}"
        provider.read this, cb
      catch error
        cb new Error "Provider type '#{@setup.type}' is not possible to read from."

  format: (worker, cb) ->
    return cb() unless @setup.data
    return cb() unless @result not in ['list', 'record']
    @data.format @setup.data.format if @setup.data.format
    if conf = @setup.data.fields?[@result]
      map = {}
      map[n] = n for n in conf
      @data.columns map
      @data.unique()
    cb()

  reference: (worker, cb) ->
    return cb() unless @setup.reference
    col = -1
    for field of @data.row 0
      col++
      if conf = @setup.reference[field]
        # add reference
        raw = @data.data
        for row in [1..raw.length-1]
          ref = conf.filter (r) ->
            # self referencing only in list
            object = r.object ? @object
            object = "#{@group}/#{object}" unless ~object.indexOf '/'
            object += "/#{r.search}/#{raw[row][col]}"
            "#{@group}/#{@object}/#{@search}/#{@values}" isnt object
          .map (r) ->
            object = r.object ? @object
            object = "#{@group}/#{object}" unless ~object.indexOf '/'
            "<a href=\"/#{object}/#{r.search}/#{raw[row][col]}\">#{r.title}</a>"
          .join ' / '
          ref = "<span class=\"reference\">#{ref}</span>"
          raw[row][col] += "<br />#{ref}"
    cb()

  output: (worker, cb) ->
    if @result is 'record'
      @data.flip()
      @data.columns {'Property': true, 'Value': true}
      @data.filter 'Value not null'
    if @data.data.length > 1
      @report.table @data, true
    else
      @report.box true, 'warning'
      @report.h3 'No records found!'
      @report.box false
      @report.p "You may correct your query parameters in the path."
    cb()


module.exports = Worker
