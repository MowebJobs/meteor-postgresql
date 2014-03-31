if Meteor.isClient
  Model = {}

if Meteor.isServer
  # import npm postgres connect package [Npm Postgres client](https://www.npmjs.org/package/pg)
  # [pg wiki](https://github.com/brianc/node-postgres/wiki)
  pg = Npm.require 'pg'

  # connect to postgres db with a user
  pgConString = "postgres://localhost/austin"

  ###
    Simple Postgre Notification Client
      * Listens on all channels
      * Persistent Connection
  ###
  NotificationClient = new pg.Client pgConString
  NotificationClient.connect()
  # postgres notification event handler
  NotificationClient.on "notification", (notification) ->
    # write record to mongo or something
    console.log "notification:#{notification.channel}"
    console.log notification
  NotificationClient.on 'error', (err) ->
    console.log "notification:error"
    console.log err

  ###
    Bookshelf ORM Initialization
      * [SQL ORM based on Backbone](http://bookshelfjs.org)
      * connect ORM to postgres
  ###
  Bookshelf = Npm.require 'bookshelf'
  Bookshelf = Bookshelf.initialize
    client: 'pg',
    connection:
      host: 'localhost'
      user: 'austin'

  Model = Bookshelf.Model




