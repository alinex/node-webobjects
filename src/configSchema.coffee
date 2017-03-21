# Configuration Schema
# =================================================


# Complete Schema Definition
# -------------------------------------------------

exports.server =
  title: "Server Setup"
  description: "the configuration for the server"
  type: 'object'
  allowedKeys: true
  keys:
    http:
      title: "Web Server Setup"
      description: "the configuration for the web server"
      type: 'object'
      allowedKeys: true
      keys:
        port:
          title: "Port Number"
          description: "the port on which to listen for incoming requests"
          type: 'port'
          default: 3000

exports.webobjects =
  title: "Webobjects Setup"
  description: "the configuration for the database report system"
  type: 'object'
  allowedKeys: true
