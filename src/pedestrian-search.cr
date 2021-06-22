require "../config/application"

VERSION = "0.1.0"

Amber::Support::ClientReload.new if Amber.settings.auto_reload?
Amber::Server.start
