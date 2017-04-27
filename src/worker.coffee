
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
    , (err, res) =>
      @values = res
      if err
        debug chalk.red "failed with: #{err.message}"
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
        cb new Error "Provider type '#{@setup.type}' is not possible to read from (#{error.message})"

  format: (cb) ->
    return cb() unless @setup.data
    return cb() unless @result in ['list', 'record']
    @data.format @setup.data.format if @setup.data.format
    if conf = @setup.data.fields?[@result]
      map = {}
      map[n] = n for n in conf
      @data.columns map
      @data.unique()
    cb()

  reference: (cb) ->
    return cb() unless @setup.reference
    col = -1
    for field of @data.row 0
      col++
      if conf = @setup.reference[field]
        # remove details if already in record view
        if @result is 'record' and not conf[0]?.object
          conf = conf[1..]
        continue unless conf.length
        # add references
        raw = @data.data
        for row in [1..raw.length-1]

          if conf.length is 1
            r = conf[0]
            object = r.object ? @object
            object = "#{@group}/#{object}" unless ~object.indexOf '/'
            if not conf[0]?.object
              raw[row][col] = "[#{raw[row][col]}](/#{object}/#{r.search}/#{raw[row][col]}
              \"#{r.title}\")"
            else
              raw[row][col] += "<br /><span class=\"reference\">\
              <a href=\"/#{object}/#{r.search}/#{raw[row][col]}\">#{r.title}</a></span>"
          else
            ref = conf.filter (r) =>
              # self referencing only in list
              object = r.object ? @object
              object = "#{@group}/#{object}" unless ~object.indexOf '/'
              object += "/#{r.search}/#{raw[row][col]}"
              "#{@group}/#{@object}/#{@search}/#{@values}" isnt object
            r = ref[0]
            object = r.object ? @object
            object = "#{@group}/#{object}" unless ~object.indexOf '/'
            firstRef = if ref[0]?.object then null
            else "[#{raw[row][col]}](/#{object}/#{r.search}/#{raw[row][col]} \"#{r.title}\")"
            if @result is 'list'
              raw[row][col] = firstRef if firstRef
              continue
            # additional references only in record view
            start = if firstRef then 1 else 0
            ref = ref[start..].map (r) =>
              object = r.object ? @object
              object = "#{@group}/#{object}" unless ~object.indexOf '/'
              "<a href=\"/#{object}/#{r.search}/#{raw[row][col]}\">#{r.title}</a>"
            .join ' / '
            ref = "<span class=\"reference\">#{ref}</span>"
            raw[row][col] = "#{firstRef ? raw[row][col]}<br />#{ref}"
    cb()

  output: (cb) ->
    if @result is 'record'
      @data.flip()
      @data.columns {'Property': true, 'Value': true}
      @data.filter 'Value not null'
    switch @result
      when 'record', 'list'
        if @data.data.length > 1
          @report.table @data, true
        else
          @report.box true, 'warning'
          @report.h3 'No records found!'
          @report.box false
          @report.p "You may correct your query parameters in the path."
      else
        if @dataTitle
          @report.box true, 'details', @dataTitle
          @report.pre @data
          @report.box false
          @report.style 'container:size=auto'

        else
          @report.pre @data
    cb()


module.exports = Worker
