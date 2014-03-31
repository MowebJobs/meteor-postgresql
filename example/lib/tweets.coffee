if Meteor.isServer
  # Tweet Model
  class @Tweet extends Model
    tableName: 'tweets'
    # belongs to a user
    users: ->
      return @belongsTo User, 'user_id'

  # Tweet Collection
  class @TweetTable extends Table
    model: Tweet