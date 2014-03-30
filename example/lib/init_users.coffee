@UserMeteorCollection = new Meteor.Collection 'Users'

if Meteor.isServer
  @NotificationClient.query "LISTEN users"

  class Tweet extends Bookshelf.Model
    tableName: 'tweets'
    users: ->
      return @belongsTo User, 'user_id'

  class TweetCollection extends Bookshelf.Collection
    model: Tweet

  class User extends Bookshelf.Model
    tableName: 'users'
    tweets: ->
      @hasMany Tweet, 'user_id'
    followers: ->
      @belongsToMany FollowerUser, 'followers', 'followee', 'follower'
    following: ->
      @belongsToMany FollowerUser, 'followers', 'follower', 'followee'

  class UserCollection extends Bookshelf.Collection
    model: User

  class FollowerUser extends Bookshelf.Model
    tableName: 'users'

  Users = new UserCollection().fetch(
    withRelated: ['tweets', 'followers', 'following']
  ).then( Meteor.bindEnvironment((collection)->
    users = collection.toJSON()
    users.forEach (user) ->
      UserMeteorCollection.upsert { id: user.id }, { $set: user }
  ))

  UserMeteorCollection.allow
    insert: (userId, doc)->
      console.log 'UserMeteorCollection:insert'
      new User().save _.pick(doc, ['username'])
      .then( Meteor.bindEnvironment( (updatedModel) ->
          console.log "UserMeteorCollection:insert:save:success"
          updatedModel.fetch
            withRelated: ['tweets', 'followers', 'following']
          .then Meteor.bindEnvironment( (user) ->
            console.log "UserMeteorCollection:insert:fetchRelated:success"
            id = UserMeteorCollection.insert user.toJSON()
            console.log "UserMeteorCollection:insert:id:#{id}"
          )
        )
      , (err)->
        console.log "UserMeteorCollection:insert:save:error"
        console.log err
      )
      return false

    update: (userId, docs, fields, modifier) ->
      console.log "UserMeteorCollection:update"
      console.log
        userId: userId
        docs: docs
        fields: fields
        modifier: modifier
      return false

    remove: (userId, docs) ->
      console.log "UserMeteorCollection:remove"
      console.log
        userId: userId
        docs: docs
      return false

  Meteor.publish 'all_users', -> UserMeteorCollection.find()

  Meteor.publish "UserMeteorCollection_count", ->
    count = 0 # the count of all users
    initializing = true # true only when we first start
    handle = UserMeteorCollection.find().observeChanges
      added: =>
        count++ # Increment the count when users are added.
        @changed "UserMeteorCollection-count", 1, {count} unless initializing
      removed: =>
        count-- # Decrement the count when users are removed.
        @changed "UserMeteorCollection-count", 1, {count}

    initializing = false

    # Call added now that we are done initializing. Use the id of 1 since
    # there is only ever one object in the collection.
    @added "UserMeteorCollection-count", 1, {count}

    # Let the client know that the subscription is ready.
    @ready()

    # Stop the handle when the user disconnects or stops the subscription.
    # This is really important or you will get a memory leak.
    @onStop -> handle.stop()

if Meteor.isClient
  UserCollectionCount = new Meteor.Collection "UserMeteorCollection-count"
  Meteor.subscribe "all_users"
  Meteor.subscribe "UserMeteorCollection_count"
  Session.setDefault "UserMeteorCollection_count", 'Waiting on Subsription'

  Deps.autorun (->
    UserCollection = UserCollectionCount.findOne()
    unless UserCollection is undefined
      Session.set "UserMeteorCollection_count", UserCollection.count
  )

  Template.users.count = ->
    return Session.get "UserMeteorCollection_count"

  Template.users.users = ->
    return UserMeteorCollection.find()

  ###
  Meteor.setInterval (->
    FooCollection.insert
      name: new Date()
  ), 100
  ###