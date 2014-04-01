Meteor.startup( ->
  # connect to postgres db with a user
  if Meteor.isServer
    # con string is postgres://host/db
    pgConString = "postgres://localhost/austin"
    console.log "Set pgConString to point at your db in example/main.coffee"
  else pgConString = null

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