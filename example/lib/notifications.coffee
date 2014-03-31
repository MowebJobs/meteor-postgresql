if Meteor.isServer
  # Start listening on the users_insert channel
  @NotificationClient.query 'LISTEN users_insert'