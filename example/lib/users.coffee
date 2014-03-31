###### Models
# A fake model to simulate a pivot table
class FollowerUser extends Model
  tableName: 'users'

# The real user model
# defined on server and client
class @User extends Model
  @collectionName: 'users'
  @meteorCollection: new Meteor.Collection User.collectionName
  tableName: User.collectionName
  @fields: ['id', 'username']
  # Related Properties
  @related: ['tweets', 'followers', 'following']
  tweets: ->
    if Meteor.isServer
      @hasMany Tweet, 'user_id'
  followers: ->
    if Meteor.isServer
      @belongsToMany FollowerUser, 'followers', 'followee', 'follower'
  following: ->
    if Meteor.isServer
      @belongsToMany FollowerUser, 'followers', 'follower', 'followee'
  @pushMongo: Meteor.bindEnvironment( (table)->
    models = table.toJSON()
    # upsert each model into the MongoDB collection
    # upsert will create a new model if none exists
    # or merge the model with the new model object
    models.forEach (model) ->
      User.meteorCollection.upsert { id: model.id }, { $set: model }
  )
  @save: (userId, doc)->
    # Create a new user from the MongoDB document
    # Calling save() persists the model to PostgreSQL
    # Notice that this only saves the model, not its related models
    new User().save _.pick(doc, User.fields)
    # Once the model is saved then insert to mongo
    .then( Meteor.bindEnvironment( (model) ->
        console.log "#{model.tableName}:save:#{model.id}"
        # retrieve an instance of this model with all of its related fields from postgres
        model.fetch
          withRelated: User.related
        # Once the related fields have been fetched
        # bindEnvironment is necssary again as this is another promise
        .then User.insertMongo
      )
    , (err)->
      console.log "#{User.collectionName}:save:error"
      console.log err
    )
    return false
  @update: (userId, docs, fields, modifier) ->
    console.log "#{User.collectionName}:update"
    console.log
      userId: userId
      docs: docs
      fields: fields
      modifier: modifier
    return false
  @remove: (userId, docs) ->
    console.log "#{User.collectionName}:remove"
    console.log
      userId: userId
      docs: docs
    return false
  @insertMongo: Meteor.bindEnvironment( (model) ->
    # insert the model into MongoDB
    _id = User.meteorCollection.insert model.toJSON()
    console.log "#{model.tableName}:insert:#{_id}"
    console.log User.meteorCollection.findOne _id: _id
  , (err)->
    console.log "#{User.collectionName}:insert:error"
    console.log err
  )
  @setAllowRules: ->
    if Meteor.isServer
      # Allow rules control the clients ability to write to MongoDB
      # This is where the write to PostgreSQL occurs
      # If the PostgreSQL write fails
      #   * then the allow rule fails
      #   * and the write is invalidated on the client
      # Other allow rules may include role validation, write access, and much more
      User.meteorCollection.allow
        # when a client inserts into the user collection
        #   * userId is the user on the client
        #     * userId is really useful for checking authorization on data changes
        #   * doc is the MongoDB document being inserted
        #     * this document has already been created on the client
        #     * if this allow rule fails the client version will be invalidated and removed
        insert: User.save
        update: User.update
        remove: User.remove
  @publish:
    all: ->
      if Meteor.isServer
        Meteor.publish "all_#{User.collectionName}", -> User.meteorCollection.find()
    count: ->
      if Meteor.isServer
        Meteor.publish "#{User.collectionName}_count", ->
          count = 0 # the count of all users
          initializing = true # true only when we first start
          handle = User.meteorCollection.find().observeChanges
            added: =>
              count++ # Increment the count when users are added.
              @changed "#{User.collectionName}-count", 1, {count} unless initializing
            removed: =>
              count-- # Decrement the count when users are removed.
              @changed "#{User.collectionName}-count", 1, {count}
          initializing = false
          # Call added now that we are done initializing. Use the id of 1 since
          # there is only ever one object in the collection.
          @added "#{User.collectionName}-count", 1, {count}
          # Let the client know that the subscription is ready.
          @ready()
          # Stop the handle when the user disconnects or stops the subscription.
          # This is really important or you will get a memory leak.
          @onStop -> handle.stop()
  # All websocket subscriptions related to this model
  # These subscriptions are defined on the client and server
  @subscribe:
    all: ->
      # On the client listen to notifications from the PostgreSQL server
      if Meteor.isServer
        # TODO : abstract these subscriptions away
        NotificationClient.query 'LISTEN "' + User.collectionName + '_INSERT"'
        NotificationClient.query 'LISTEN "' + User.collectionName + '_UPDATE"'
        NotificationClient.query 'LISTEN "' + User.collectionName + '_DELETE"'
      # On the client listen to changes in the all_users publication
      if Meteor.isClient
        Meteor.subscribe "all_#{User.collectionName}"
    count: ->
      # On the client create a collection and subscribe the the user_count publication
      if Meteor.isClient
        Session.setDefault "#{User.collectionName}_count", 'Waiting on Subsription'
        if User.count is undefined
          User.count = new Meteor.Collection "#{User.collectionName}-count"
        Meteor.subscribe "#{User.collectionName}_count"
        Deps.autorun (->
          users = User.count.findOne()
          unless users is undefined
            Session.set "#{User.collectionName}_count", users.count
        )
  @syncronizeMongoDB: ->
    if Meteor.isServer
      User.collection().fetch(
        # build a complete user collection with all related fields
        # TODO : abstract the related fields declaration
        withRelated: User.related
      ).then( User.pushMongo
        , (err)->
          console.log "#{User.collectionName}:sync:error"
          console.log err
      )
  @initialize: ->
    if Meteor.isServer
      User.setAllowRules()
      User.syncronizeMongoDB()
      User.publish.all()
      User.publish.count()
    User.subscribe.all()
    User.subscribe.count()

###### Views
if Meteor.isClient
  Template.users.count = ->
    return Session.get "#{User.collectionName}_count"

  Template.users.users = ->
    return User.meteorCollection.find()