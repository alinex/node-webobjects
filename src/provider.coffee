
# Main controlling class
# =================================================



# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug') 'webobjects:data'
chalk = require 'chalk'
util = require 'util'
# include alinex modules
Database = require 'alinex-database'
validator = require 'alinex-validator'
Table = require 'alinex-table'


exports.read = (setup, work, cb) ->
  # validate call
  if work.search not in Object.keys setup.get
    return cb new Error "Access type '#{work.search}' is not defined."
  conf = setup.get[work.search]
  validator.check
    name: 'params'
    value: work.values
    schema: conf.params
  , (err, res) ->
    work.values = res
    if err
      debug chalk.red "    failed with: #{err.message}"
      validator.describe
        name: 'params'
        schema: conf.params
      , (_, text) ->
        cb new Error "### #{err.message}.\n\n#{text}"
      return
    # fetch data
    switch setup.type
      when 'database' then readDatabase setup, work, cb
      else cb new Error "Provider type '#{setup.type}' is not possible."

readDatabase = (setup, work, cb) ->
  conf = setup.get[work.search]
  params = work.values
  params = if Array.isArray params
    params.map (e) ->
      switch typeof e
        when 'number' then e
        else "'#{e.replace /'/g, "''"}'"
    .join ','
  else
    switch typeof params
      when 'number' then params
      else "'#{params.replace /'/g, "''"}'"
  query = conf.query.replace '?', params
  Database.list setup.connection, query, (err, list) ->
    return cb err if err
    work.data = (new Table()).fromRecordObject list
    work.data.unique()
    work.result = if list.length > 1 then 'list' else 'record'
    cb()

exports.format = (setup, work, cb) ->
  return cb() unless setup.data
  work.data.format setup.data.format if setup.data.format
  if conf = setup.data.fields?[work.result]
    map = {}
    map[n] = n for n in conf
    work.data.columns map
    work.data.unique()
  cb()

exports.reference = (setup, work, cb) ->
  return cb() unless setup.reference
  col = -1
  for field of work.data.row 0
    col++
    if conf = setup.reference[field]
      # add reference
      raw = work.data.data
      for row in [1..raw.length-1]
        ref = conf.filter (r) ->
          # self referencing only in list
          work.result isnt 'record' or r.object
        .map (r) ->
          object = r.object ? work.object
          object = "#{work.group}/#{object}" unless ~object.indexOf '/'
          "<a href=\"/#{object}/#{r.search}/#{raw[row][col]}\">#{r.title}</a>"
        .join ' / '
        ref = "<span class=\"reference\">#{ref}</span>"
        raw[row][col] += "<br />#{ref}"
  cb()

exports.flip = (setup, work, cb) ->
  return cb() unless work.result is 'record'
  work.data.flip()
  work.data.columns {'Property': true, 'Value': true}
  work.data.filter 'Value not null'
  cb()
