Meteor.startup( ->
  # connect to postgres db with a user
  if Meteor.isServer
    pgConString = "postgres://localhost/austin"
  else pgConString = null

  # create a persistent connection with postgres to monitor notifications
  Mediator.initialize(pgConString)

  User.initialize()
  User.subscribe.all()
  User.subscribe.count()

  Foo.initialize(pgConString)
  Foo.publish.count()
  Foo.subscribe.count()
)

if Meteor.isClient
  Template.foo.test = ->
    return Session.get 'test'

  Template.foo.count = ->
    return Session.get "#{Foo.collectionName}_count"

  Template.foo.events
    'click button': ->
      Foo.test = !Foo.test


  Meteor.setInterval (->
    Session.set 'test', Foo.test
    if Foo.test
      Foo.meteorCollection.insert
        name: new Date()
  ), 1000