# Database Operations
# ==================================================


# Node Modules
# -------------------------------------------------

# include alinex modules
util = require 'alinex-util'
Exec = require 'alinex-exec'
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
  # get data
  args = if conf.args
    conf.args.map (e) -> e.replace '?', params
  sum = if args
    args.map((e) -> util.inspect e).join ' '
  worker.code =
    data: "#{conf.cmd} #{sum ? ''}"
    language: 'bash'
    title: "#{conf.remote ? 'localhost'}"
  Exec.run
    remote: conf.remote
    cmd: conf.cmd
    args: args
    check: conf.check
  , (err, proc) ->
    return cb err if err
    worker.data = proc.stdout().trim()
    worker.data = "No entries found." unless worker.data.length
    worker.dataTitle = conf.result if conf.result
    worker.result = 'text'
    cb()
