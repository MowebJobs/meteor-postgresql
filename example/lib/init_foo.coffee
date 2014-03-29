@Foo = new Meteor.Collection 'foo'

Meteor.startup ->
  Foo.postgre.listen()
  Foo.postgre.sync()

Foo.postgre =
  listen: ->
    if Meteor.isServer
      NotificationClient.query "LISTEN foo"
  sync: ->
    if Meteor.isServer
      if Foo.find().count() is 0
        pg.connect pgConString, Meteor.bindEnvironment( (err, client, done) ->
          console.log "foo:sync:start"
          sync = client.query
            name: "foo:sync"
            text: "SELECT * FROM foo"
          sync.on 'row', (row, result) ->
            result.addRow row
          sync.on 'error', (err) ->
            console.log "foo:sync:error"
            console.log err
          sync.on 'end', Meteor.bindEnvironment( (result) ->
            console.log "foo:sync:end"
            console.log "#{result.rows.length} rows were received"
            unless result.rows.length is 0
              result.rows.forEach (row) ->
                Foo.insert row
          )
          done()
        )

Foo.allow
  insert: (userId, doc)->
    pg.connect pgConString, (err, client, done) ->
      throw err if err
      insert = client.query
        name: "foo:insert"
        text: "INSERT INTO foo ( name ) VALUES ( $1 )"
        values: [ doc.name ]
      insert.on 'row', (row, result) ->
        console.log "foo:insert:row"
        result.addRow row
      insert.on 'error', (err) ->
        console.log "foo:insert:error"
        console.log err
      insert.on 'end', (result) ->
        console.log "foo:insert:end"
        console.log "#{result.rows.length} rows were received"
        @allow = true
      done()
    return true

  update: (userId, docs, fields, modifier) ->
    console.log "foo:update"
    console.log
      userId: userId
      docs: docs
      fields: fields
      modifier: modifier
    return true

  remove: (userId, docs) ->
    console.log "foo:remove"
    console.log
      userId: userId
      docs: docs
    return true

if Meteor.isServer
  Meteor.publish "foo_count", ->
    count = 0 # the count of all users
    initializing = true # true only when we first start
    handle = Foo.find().observeChanges
      added: =>
        count++ # Increment the count when users are added.
        @changed "foo-count", 1, {count} unless initializing
      removed: =>
        count-- # Decrement the count when users are removed.
        @changed "foo-count", 1, {count}

    initializing = false

    # Call added now that we are done initializing. Use the id of 1 since
    # there is only ever one object in the collection.
    @added "foo-count", 1, {count}

    # Let the client know that the subscription is ready.
    @ready()

    # Stop the handle when the user disconnects or stops the subscription.
    # This is really important or you will get a memory leak.
    @onStop -> handle.stop()


if Meteor.isClient
  FooCount = new Meteor.Collection "foo-count"
  Meteor.subscribe "foo_count"
  Session.setDefault "foo_count", 'Waiting on Subsription'

  Deps.autorun (->
    foo = FooCount.findOne()
    unless foo is undefined
      Session.set "foo_count", foo.count
  )

  Template.foo.count = ->
    return Session.get "foo_count"

  Meteor.setInterval (->
    Foo.insert
      name: new Date()
  ), 100



