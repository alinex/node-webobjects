
# Main controlling class
# =================================================



# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug') 'webobjects:data'
chalk = require 'chalk'
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
  query = conf.query.replace '?', work.values.join ','
  Database.list setup.connection, query, (err, list) ->
    return cb err if err
    work.data = (new Table()).fromRecordObject list
    work.result = if list.length > 1 then 'list' else 'record'
    cb()
