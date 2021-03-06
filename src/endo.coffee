_                        = require 'lodash'
MeshbluHTTP              = require 'meshblu-http'

CredentialsDeviceService = require './services/credentials-device-service'
MessagesService          = require './services/messages-service'
MessageRouter            = require './models/message-router'

Server                   = require './server'
FirehoseMessageProcessor = require './firehose-message-processor'

class Endo
  constructor: (options) ->
    {
      @apiStrategy
      @appOctobluHost
      @deviceType
      @disableLogging
      @logFn
      @firehoseMeshbluConfig
      @healthcheckService
      @meshbluConfig
      @meshbluPublicKeyUri
      @messageHandler
      @octobluStrategy
      @port
      @serviceUrl
      @skipExpress
      @skipRedirectAfterApiAuth
      @staticSchemasPath
      @userDeviceManagerUrl
      @useFirehose
      @refreshTokenHandler
    } = options

    throw new Error('messageHandler is required') unless @messageHandler?
    throw new Error('deviceType is required') unless @deviceType?
    throw new Error('serviceUrl is required') unless @serviceUrl?

    unless @skipExpress
      throw new Error 'healthcheckService is required' unless @healthcheckService?
      throw new Error 'healthcheckService.healthcheck is not a function (and must be)' unless _.isFunction @healthcheckService.healthcheck

  address: =>
    @server?.address()

  run: (callback) =>
    meshblu = new MeshbluHTTP @meshbluConfig
    meshblu.whoami (error, device) =>
      return callback new Error("Could not authenticate with meshblu: #{error.message}") if error?

      {imageUrl} = device.options ? {}
      credentialsDeviceService  = new CredentialsDeviceService {@meshbluConfig, @serviceUrl, @deviceType, @refreshTokenHandler, imageUrl}
      messagesService           = new MessagesService {@meshbluConfig, @messageHandler}
      messageRouter             = new MessageRouter {@meshbluConfig, messagesService, credentialsDeviceService}

      callback = _.after callback, 2 if @useFirehose && !@skipExpress
      unless @skipExpress
        @server = new Server {
          @apiStrategy
          @appOctobluHost
          credentialsDeviceService
          @disableLogging
          @healthcheckService
          @logFn
          @meshbluConfig
          @meshbluPublicKeyUri
          messagesService
          messageRouter
          @octobluStrategy
          @port
          @serviceUrl
          @skipRedirectAfterApiAuth
          @staticSchemasPath
          @userDeviceManagerUrl
        }
        @server.run callback

      if @useFirehose
        @firehoseMeshbluConfig ?= @meshbluConfig
        @firehose = new FirehoseMessageProcessor {meshbluConfig: @firehoseMeshbluConfig, messageRouter}
        @firehose.run callback

  stop: (callback) =>
    callback = _.after callback, 2 if @useFirehose && !@skipExpress
    @server?.stop callback
    @firehose?.stop callback

module.exports = Endo
