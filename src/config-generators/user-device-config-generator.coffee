module.exports = ({authorizedUuid, credentialsUuid, deviceType, imageUrl}) ->
  type: deviceType
  imageUrl: imageUrl
  octoblu:
    flow:
      forwardMetadata: true
  meshblu:
    version: '2.0.0'
    whitelists:
      broadcast:
        as:       [{uuid: authorizedUuid}]
        received: [{uuid: authorizedUuid}]
        sent:     [{uuid: authorizedUuid}]
      configure:
        as:       [{uuid: authorizedUuid}]
        received: [{uuid: authorizedUuid}]
        sent:     [{uuid: authorizedUuid}]
        update:   [{uuid: authorizedUuid}]
      discover:
        view:     [{uuid: authorizedUuid}]
        as:       [{uuid: authorizedUuid}]
      message:
        as:       [{uuid: authorizedUuid}, {uuid: credentialsUuid}]
        received: [{uuid: authorizedUuid}, {uuid: credentialsUuid}]
        sent:     [{uuid: authorizedUuid}]
        from:     [{uuid: authorizedUuid}]