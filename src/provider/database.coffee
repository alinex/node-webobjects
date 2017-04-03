# Database Operations
# ==================================================


# Node Modules
# -------------------------------------------------

# include alinex modules
Database = require 'alinex-database'
Table = require 'alinex-table'


exports.read = (worker, cb) ->
  conf = worker.setup.get[worker.search]
  params = worker.values
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
  query = conf.query.trim().replace '?', params
  worker.code =
    data: query
    language: 'sql'
    title: worker.setup.connection.toString()
  Database.list worker.setup.connection, query, (err, list) ->
    return cb err if err
    worker.data = (new Table()).fromRecordObject list
    worker.data.unique()
    worker.result = if list.length > 1 then 'list' else 'record'
    cb()
