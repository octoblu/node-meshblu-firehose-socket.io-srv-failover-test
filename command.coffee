async         = require 'async'
dashdash      = require 'dashdash'
MeshbluConfig = require 'meshblu-config'
MeshbluHttp   = require 'meshblu-http'
Firehose      = require 'meshblu-firehose-socket.io'
UUID          = require 'uuid'

packageJSON = require './package.json'

OPTIONS = [{
  names: ['help', 'h']
  type: 'bool'
  help: 'Print this help and exit.'
}, {
  names: ['version', 'v']
  type: 'bool'
  help: 'Print the version and exit.'
}]

class Command
  constructor: ->
    process.on 'uncaughtException', @die
    @parseOptions()
    @nonce = UUID.v1()
    @meshbluConfig = new MeshbluConfig()
    @meshblu  = new MeshbluHttp @meshbluConfig.toJSON()
    @firehose = new Firehose meshbluConfig: @meshbluConfig.toJSON()

  parseOptions: =>
    parser = dashdash.createParser({options: OPTIONS})
    options = parser.parse(process.argv)

    if options.help
      console.log @usage parser.help({includeEnv: true})
      process.exit 0

    if options.version
      console.log packageJSON.version
      process.exit 0

    return options

  run: =>
    async.parallel [@createSubscriptions, @firehose.connect], (error) =>
      return @die error if error?

      @firehose.on 'message', (message) =>
        return @die new Error 'Recieved wrong message' unless message.data.nonce == @nonce
        console.log JSON.stringify(message.data, null, 2)
        return @die()

      @meshblu.message {devices: ['*'], @nonce}, (error) =>
        return @die error if error?

  createSubscriptions: (callback) =>
    {uuid} = @meshbluConfig.toJSON()
    subscriptions = [
      {type: 'broadcast.sent',     emitterUuid: uuid, subscriberUuid: uuid}
      {type: 'broadcast.received', emitterUuid: uuid, subscriberUuid: uuid}
    ]
    async.each subscriptions, @meshblu.createSubscription, callback

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

  usage: (optionsStr) =>
    """
    usage: node-meshblu-firehose-socket-io-srv-failover-test [OPTIONS]
    options:
    #{optionsStr}
    """

module.exports = Command
