@FooCollection = new Meteor.Collection 'FooCollection'

Meteor.startup ->
  FooCollection.postgre.listen()
  FooCollection.postgre.sync()

FooCollection.postgre =
  listen: ->
    if Meteor.isServer
      NotificationClient.query "LISTEN foo"
  sync: ->
    if Meteor.isServer
      if FooCollection.find().count() is 0
        pg.connect pgConString, Meteor.bindEnvironment( (err, client, done) ->
          console.log "FooCollection:sync:start"
          sync = client.query
            name: "FooCollection:sync"
            text: "SELECT * FROM foo"
          sync.on 'row', (row, result) ->
            result.addRow row
          sync.on 'error', (err) ->
            console.log "FooCollection:sync:error"
            console.log err
          sync.on 'end', Meteor.bindEnvironment( (result) ->
            console.log "FooCollection:sync:end"
            console.log "#{result.rows.length} rows were received"
            unless result.rows.length is 0
              result.rows.forEach (row) ->
                FooCollection.insert row
          )
          done()
        )

FooCollection.allow
  insert: (userId, doc)->
    pg.connect pgConString, (err, client, done) ->
      throw err if err
      insert = client.query
        name: "FooCollection:insert"
        text: "INSERT INTO foo ( name ) VALUES ( $1 )"
        values: [ doc.name ]
      insert.on 'row', (row, result) ->
        console.log "FooCollection:insert:row"
        result.addRow row
      insert.on 'error', (err) ->
        console.log "FooCollection:insert:error"
        console.log err
      insert.on 'end', (result) ->
        console.log "FooCollection:insert:end"
        console.log "#{result.rows.length} rows were received"
        @allow = true
      done()
    return true

  update: (userId, docs, fields, modifier) ->
    console.log "FooCollection:update"
    console.log
      userId: userId
      docs: docs
      fields: fields
      modifier: modifier
    return true

  remove: (userId, docs) ->
    console.log "FooCollection:remove"
    console.log
      userId: userId
      docs: docs
    return true

if Meteor.isServer
  class Foo extends Bookshelf.Model
    tableName: 'foo'

  Meteor.publish "FooCollection_count", ->
    count = 0 # the count of all users
    initializing = true # true only when we first start
    handle = FooCollection.find().observeChanges
      added: =>
        count++ # Increment the count when users are added.
        @changed "FooCollection-count", 1, {count} unless initializing
      removed: =>
        count-- # Decrement the count when users are removed.
        @changed "FooCollection-count", 1, {count}

    initializing = false

    # Call added now that we are done initializing. Use the id of 1 since
    # there is only ever one object in the collection.
    @added "FooCollection-count", 1, {count}

    # Let the client know that the subscription is ready.
    @ready()

    # Stop the handle when the user disconnects or stops the subscription.
    # This is really important or you will get a memory leak.
    @onStop -> handle.stop()


if Meteor.isClient
  FooCollectionCount = new Meteor.Collection "FooCollection-count"
  Meteor.subscribe "FooCollection_count"
  Session.setDefault "FooCollection_count", 'Waiting on Subsription'

  Deps.autorun (->
    FooCollection = FooCollectionCount.findOne()
    unless FooCollection is undefined
      Session.set "FooCollection_count", FooCollection.count
  )

  Template.foo.count = ->
    return Session.get "FooCollection_count"

  ###
  Meteor.setInterval (->
    FooCollection.insert
      name: new Date()
  ), 100
  ###



