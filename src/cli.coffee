# Startup script
# =================================================


# Node Modules
# -------------------------------------------------

# include base modules
yargs = require 'yargs'
chalk = require 'chalk'
path = require 'path'
# include alinex modules
fs = require 'alinex-fs'
alinex = require 'alinex-core'
util = require 'alinex-util'
config = require 'alinex-config'
# include classes and helpers
webobjects = require './index'

process.title = 'WebObjects'
logo = alinex.logo 'WebObjects Browser'


# Support quiet mode through switch
# -------------------------------------------------
quiet = false
for a in ['--get-yargs-completions', 'bashrc', '-q', '--quiet']
  quiet = true if a in process.argv


# Error management
# -------------------------------------------------
alinex.initExit()
process.on 'exit', ->
  console.log "Goodbye\n" unless quiet


# Support quiet mode through switch
# -------------------------------------------------
quiet = false
for a in ['--get-yargs-completions', 'bashrc', '-q', '--quiet']
  quiet = true if a in process.argv


# Main routine
# -------------------------------------------------
unless quiet
  console.log logo
  console.log chalk.grey "Initializing..."

webobjects.setup (err) ->
  alinex.exit 16, err if err
  # Start argument parsing
  yargs
  .usage "\nUsage: $0 <command> [options] [dir]..."
  .env 'WEBOBJECTS' # use environment arguments prefixed with SCRIPTER_
  # examples
  .example '$0 test -vb', 'to run the tests till first failure'
  # general options
  .options
    help:
      alias: 'h',
      description: 'display help message'
    nocolors:
      alias: 'C'
      describe: 'turn of color output'
      type: 'boolean'
      global: true
    verbose:
      alias: 'v'
      describe: 'run in verbose mode (multiple makes more verbose)'
      count: true
      global: true
    quiet:
      alias: 'q'
      describe: "don't output header and footer"
      type: 'boolean'
      global: true
  # help
  yargs.help 'help'
  .updateStrings
    'Options:': 'General Options:'
  .epilogue """
    You may use environment variables prefixed with 'WEBOBJECTS_' to set any of
    the options like 'WEBOBJECTS_VERBOSE' to set the verbose level.

    For more information, look into the man page.
    """
  .completion 'bashrc-script', false
  # validation
  .strict()
  .fail (err) ->
    err = new Error "CLI #{err}"
    err.description = 'Specify --help for available options'
    alinex.exit 2, err
  # now parse the arguments
  argv = yargs.argv
  # check for correct call
  console.log chalk.grey "Starting server..."
  config.init (err) ->
    throw cb err if err
    webobjects.start()
