if Meteor.isServer
  Meteor.startup ->
    # import npm postgres connect package [Npm Postgres client](https://www.npmjs.org/package/pg)
    # [pg wiki](https://github.com/brianc/node-postgres/wiki)
    @pg = Npm.require "pg"
    # connect to postgres db with a user
    @pgConString = "postgres://localhost/austin"

    ###
      Simple Postgre Notification Client
        * Listens on all channels
        * Persistent Connection
    ###
    @NotificationClient = new @pg.Client @pgConString
    @NotificationClient.connect()
    # postgres notification event handler
    @NotificationClient.on "notification", (msg) ->
      # write record to mongo or something
      console.log "#{msg.channel}:notification"
      console.log msg.payload
    @NotificationClient.on 'error', (err) -> throw err




