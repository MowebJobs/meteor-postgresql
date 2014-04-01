Meteor.startup( ->
  # connect to postgres db with a user
  if Meteor.isServer
    pgConString = "postgres://localhost/austin"
  else pgConString = null

  Mediator.initialize(pgConString)
  User.initialize()
  User.subscribe.all()
  User.subscribe.count()

  Foo.initialize(pgConString)
  Foo.publish.count()
  Foo.subscribe.count()
)

if Meteor.isClient
  Template.foo.count = ->
    return Session.get "#{Foo.collectionName}_count"

  Meteor.setInterval (->
    if Foo.test
      Foo.meteorCollection.insert
        name: new Date()
  ), 1000