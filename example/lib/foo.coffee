class @Foo
  @initialize: _.once( (pgConString = null) ->
    if Meteor.isServer
      Foo.pgConString = pgConString
    Foo.connect()
    Foo.listen()
    Foo.setAllowRules()
    Foo.sync()
  )

  # test flag for inserting foos
  @test: false

  # wrapping console log
  @log: console.log

  # MongoDB
  @collectionName: 'foo'
  @meteorCollection: new Meteor.Collection Foo.collectionName

  # PostgreSQL
  tableName: Foo.collectionName

  # Connect to the PostgreSQL notification channels
  @connect: _.once( ->
    if Meteor.isServer
      unless Foo.pgConString
        Foo.log "#{Foo.collectionName}:connect:error"
        Foo.log "pgConstring undefined"
        return
      # Define PostgreSQL client
      Foo.client = new pg.Client Foo.pgConString
      # Create persistent connection to PostgreSQL
      Foo.client.connect()
      # postgres notification event handler
      Foo.client.on "notification", (notification) ->
        # write record to mongo or something
        Foo.log "#{Foo.collectionName}:notification:#{notification.channel}"
        Foo.log notification
      Foo.client.on 'error', (err) ->
        Foo.log "mediator:client:error"
        Foo.log err
  )

  # Listen to the PostgreSQL notification channels defined by channel
  @listen: ->
    if Meteor.isServer and Foo.client
      Foo.client.query 'LISTEN "' + Foo.collectionName + '_INSERT"'
      Foo.client.query 'LISTEN "' + Foo.collectionName + '_UPDATE"'
      Foo.client.query 'LISTEN "' + Foo.collectionName + '_DELETE"'
      
  # sync mongoDB to PostgreSQL table
  @sync: _.once( ->
    if Meteor.isServer and Foo.meteorCollection
      if Foo.meteorCollection.find().count() is 0
        pg.connect Foo.pgConString, Meteor.bindEnvironment( (err, client, done) ->
          console.log "#{Foo.collectionName}:sync:start"
          sync = client.query
            name: "#{Foo.collectionName}:sync"
            text: "SELECT * FROM #{Foo.collectionName}"
          sync.on 'row', (row, result) ->
            result.addRow row
          sync.on 'error', (err) ->
            console.log "#{Foo.collectionName}:sync:error"
            console.log err
          sync.on 'end', Meteor.bindEnvironment( (result) ->
            console.log "#{Foo.collectionName}:sync:end"
            console.log "#{result.rows.length} rows were received"
            unless result.rows.length is 0
              result.rows.forEach (row) ->
                Foo.meteorCollection.insert row
          )
          done()
        )
  )

  # set MongoDB write allow rules
  @setAllowRules: _.once( ->
    if Meteor.isServer
      Foo.meteorCollection.allow
        insert: (userId, doc)->
          pg.connect Foo.pgConString, (err, client, done) ->
            throw err if err
            insert = client.query
              name: "#{Foo.collectionName}:insert"
              text: "INSERT INTO #{Foo.collectionName} ( name ) VALUES ( $1 )"
              values: [ doc.name ]
            insert.on 'row', (row, result) ->
              console.log "#{Foo.collectionName}:insert:row"
              result.addRow row
            insert.on 'error', (err) ->
              console.log "#{Foo.collectionName}:insert:error"
              console.log err
            insert.on 'end', (result) ->
              @allow = true
            done()
          return true
        update: (userId, docs, fields, modifier) ->
          console.log "#{Foo.collectionName}:update"
          console.log
            userId: userId
            docs: docs
            fields: fields
            modifier: modifier
          return true
        remove: (userId, docs) ->
          console.log "#{Foo.collectionName}:remove"
          console.log
            userId: userId
            docs: docs
          return true
  )

  # publish mongoDB collections and reactive cursors
  @publish:
    count: _.once(->
      if Meteor.isServer
        Meteor.publish "#{Foo.collectionName}_count", ->
          count = 0 # the count of all users
          initializing = true # true only when we first start
          handle = Foo.meteorCollection.find().observeChanges
            added: =>
              count++ # Increment the count when users are added.
              @changed "#{Foo.collectionName}-count", 1, {count} unless initializing
            removed: =>
              count-- # Decrement the count when users are removed.
              @changed "#{Foo.collectionName}-count", 1, {count}
          initializing = false
          # Call added now that we are done initializing. Use the id of 1 since
          # there is only ever one object in the collection.
          @added "#{Foo.collectionName}-count", 1, {count}
          # Let the client know that the subscription is ready.
          @ready()
          # Stop the handle when the user disconnects or stops the subscription.
          # This is really important or you will get a memory leak.
          @onStop -> handle.stop()
    )

  # subscribe to reactive collections and cursors
  @subscribe:
    # client only collection of the total foo count
    count: ->
      if Meteor.isClient
        FooCollectionCount = new Meteor.Collection "#{Foo.collectionName}-count"
        Meteor.subscribe "#{Foo.collectionName}_count"
        Session.setDefault "#{Foo.collectionName}_count", 'Waiting on Subsription'
        Deps.autorun (->
          foo = FooCollectionCount.findOne()
          unless foo is undefined
            Session.set "#{Foo.collectionName}_count", foo.count
        )