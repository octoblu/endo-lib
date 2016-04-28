fs          = require 'fs'
{Validator} = require 'jsonschema'
_           = require 'lodash'
Encryption  = require 'meshblu-encryption'
MeshbluHTTP = require 'meshblu-http'
path        = require 'path'

ENDO_MESSAGE_INVALID   = 'Message does not match endo schema'
JOB_TYPE_UNSUPPORTED   = 'That jobType is not supported'
JOB_TYPE_UNIMPLEMENTED = 'That jobType has not yet been implemented'
MESSAGE_DATA_INVALID   = 'Message data does not match schema for jobType'
MISSING_ROUTE_HEADER   = 'Missing x-meshblu-route header in request'

class MessagesService
  constructor: ({@messageHandlers, @schemas}) ->
    throw new Error 'messageHandlers are required' unless @messageHandlers?
    throw new Error 'schemas are required' unless @schemas?

    @endoMessageSchema = @_getEndoMessageSchemaSync()
    @validator = new Validator

  reply: ({auth, route, code, response}, callback) =>
    return callback @_userError(MISSING_ROUTE_HEADER, 422) if _.isEmpty route
    firstHop       = _.first JSON.parse route
    senderUuid     = firstHop.from
    userDeviceUuid = firstHop.to

    message =
      devices: [senderUuid]
      metadata:
        code: code
      data:
        response

    meshblu = new MeshbluHTTP auth
    meshblu.message message, as: userDeviceUuid, callback

  replyWithError: ({auth, error, res, route}, callback) =>
    return callback @_userError(MISSING_ROUTE_HEADER, 422) if _.isEmpty route
    firstHop       = _.first JSON.parse route
    senderUuid     = firstHop.from
    userDeviceUuid = firstHop.to

    message =
      devices: [senderUuid]
      metadata:
        code: error.code ? 500
        error:
          message: error.message

    meshblu = new MeshbluHTTP auth
    meshblu.message message, as: userDeviceUuid, callback

  send: ({auth, endo, message}, callback) =>
    data    = message?.data
    jobType = message?.metadata?.jobType
    return callback @_userError(ENDO_MESSAGE_INVALID,   422) unless @_isValidEndoMessage message
    return callback @_userError(JOB_TYPE_UNSUPPORTED,   422) unless @_isSupportedJobType jobType
    return callback @_userError(MESSAGE_DATA_INVALID,   422) unless @_isValidMessageData jobType, message.data
    return callback @_userError(JOB_TYPE_UNIMPLEMENTED, 501) unless @_isImplemented    jobType

    encryption = Encryption.fromJustGuess auth.privateKey
    secrets = encryption.decryptOptions endo.secrets

    @messageHandlers[jobType] {data, secrets}, callback

  _getEndoMessageSchemaSync: =>
    filepath = path.join __dirname, '../../endo-message-schema.json'
    JSON.parse fs.readFileSync(filepath, 'utf8')

  _isImplemented: (jobType) =>
    _.isFunction @messageHandlers[jobType]

  _isSupportedJobType: (jobType) =>
    @schemas[jobType]?

  _isValidEndoMessage: (message) =>
    {errors} = @validator.validate message, @endoMessageSchema
    _.isEmpty errors

  _isValidMessageData: (jobType, data) =>
    {errors} = @validator.validate data, @schemas[jobType]
    _.isEmpty errors

  _userError: (message, code) =>
    error = new Error message
    error.code = code if code?
    return error

module.exports = MessagesService
