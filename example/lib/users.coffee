###### Models
# A fake model to simulate a pivot table
class FollowerUser extends Model
  tableName: 'users'

# The real user model
# defined on server and client
class @User extends Model
  ###### PostgreSQL
  tableName: 'users'
  tweets: ->
    if Meteor.isServer
      @hasMany Tweet, 'user_id'
  followers: ->
    if Meteor.isServer
      @belongsToMany FollowerUser, 'followers', 'followee', 'follower'
  following: ->
    if Meteor.isServer
      @belongsToMany FollowerUser, 'followers', 'follower', 'followee'
  ###### MongoDB
  @meteorCollection: new Meteor.Collection 'users'
  @pushMongo: Meteor.bindEnvironment( (table)->
    models = table.toJSON()
    # upsert each model into the MongoDB collection
    # upsert will create a new model if none exists
    # or merge the model with the new model object
    models.forEach (model) ->
      User.meteorCollection.upsert { id: model.id }, { $set: model }
  )
  @insertMongo: Meteor.bindEnvironment( (model) ->
    console.log "#{model.tableName}:save:#{model.id}"
    user = new User model
    console.log user
    model.fetch
      # TODO : abstract the related fields declaration
      withRelated: ['tweets', 'followers', 'following']
    # Once the related fields have been fetched
    # bindEnvironment is necssary again as this is another promise
    .then Meteor.bindEnvironment( (model) ->
        console.log "#{model.tableName}:insert"
        # insert the model into MongoDB
        _id = User.meteorCollection.insert model.toJSON()
        console.log "#{model.tableName}:insert:#{_id}"
        console.log User.meteorCollection.findOne _id: _id
      , (err)->
        console.log "insert:mongo:error"
        console.log err
      )
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
        insert: (userId, doc)->
          # Create a new user from the MongoDB document
          # Calling save() persists the model to PostgreSQL
          # Notice that this only saves the model, not its related models
          #   * TODO : the property picking needs to be abstracted
          new User().save _.pick(doc, ['username'])
          # Once the model is saved then insert to mongo
          .then( User.insertMongo
            , (err)->
              console.log "insert:save:error"
              console.log err
          )
          return false
        update: (userId, docs, fields, modifier) ->
          console.log ":update"
          console.log
            userId: userId
            docs: docs
            fields: fields
            modifier: modifier
          return false
        remove: (userId, docs) ->
          console.log ":remove"
          console.log
            userId: userId
            docs: docs
          return false
  @publish:
    all: ->
      if Meteor.isServer
        Meteor.publish 'all_users', -> User.meteorCollection.find()
    count: ->
      if Meteor.isServer
        Meteor.publish "user_count", ->
          count = 0 # the count of all users
          initializing = true # true only when we first start
          handle = User.meteorCollection.find().observeChanges
            added: =>
              count++ # Increment the count when users are added.
              @changed "user-count", 1, {count} unless initializing
            removed: =>
              count-- # Decrement the count when users are removed.
              @changed "user-count", 1, {count}
          initializing = false
          # Call added now that we are done initializing. Use the id of 1 since
          # there is only ever one object in the collection.
          @added "user-count", 1, {count}
          # Let the client know that the subscription is ready.
          @ready()
          # Stop the handle when the user disconnects or stops the subscription.
          # This is really important or you will get a memory leak.
          @onStop -> handle.stop()
  @subscribe:
    all: ->
      if Meteor.isClient
        Meteor.subscribe "all_users"
    count: ->
      if Meteor.isClient
        Session.setDefault "user_count", 'Waiting on Subsription'
        User.count = new Meteor.Collection "user-count"
        Meteor.subscribe "user_count"
        Deps.autorun (->
          users = User.count.findOne()
          unless users is undefined
            Session.set "user_count", users.count
        )
  @syncronizeMongoDB: ->
    if Meteor.isServer
      User.collection().fetch(
        # build a complete user collection with all related fields
        # TODO : abstract the related fields declaration
        withRelated: ['tweets', 'followers', 'following']
      ).then( User.pushMongo
        , (err)->
          console.log "users:sync:error"
          console.log err
      )
  @initialize: ->
    if Meteor.isServer
      User.setAllowRules()
      User.syncronizeMongoDB()
      User.publish.all()
      User.publish.count()
    if Meteor.isClient
      User.subscribe.all()
      User.subscribe.count()

###### Views
if Meteor.isClient
  Template.users.count = ->
    return Session.get "user_count"

  Template.users.users = ->
    return User.meteorCollection.find()