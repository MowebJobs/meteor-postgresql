###
  Mediator Notification Client
    * Present on both client and server
    * Mediator.log wraps console.log
    * Listens to postgres notification channels defined by Mediator.listen
    * Listens on all operations by default ( INSERT, UPDATE, DELETE
    * Persistent Connection to PostgreSQL
    * Reactive notification to client and server

  Example PostgreSQL Trigger
    -- Trigger: watched_table on users
    -- DROP TRIGGER watched_table ON users;
    CREATE TRIGGER watched_table
      AFTER INSERT OR UPDATE OR DELETE
      ON users
      FOR EACH ROW
      EXECUTE PROCEDURE notify_trigger();

  Example PostgreSQL Trigger Function
    -- Function: notify_trigger()
    -- DROP FUNCTION notify_trigger();
    CREATE OR REPLACE FUNCTION notify_trigger()
      RETURNS trigger AS
    $BODY$
    DECLARE
      channel varchar;
      JSON varchar;
    BEGIN
      -- TG_TABLE_NAME is the name of the table who's trigger called this function
      -- TG_OP is the operation that triggered this function: INSERT, UPDATE or DELETE.
      -- channel is formatted like 'users_INSERT'
      channel = TG_TABLE_NAME || '_' || TG_OP;
      JSON = (SELECT row_to_json(new));
      PERFORM pg_notify( channel, JSON );
      RETURN new;
    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
      COST 100;
    ALTER FUNCTION notify_trigger()
      OWNER TO postgresql;
###
class Mediator
  # Wrap console log, common best practice
  @log: (msg) ->
    # Eventually server logs may be written to database and client logs handled by UI
    console.log msg

  # Initializes Mediator on client and server
  @initialize: _.once( (pgConString) ->
    Mediator.connect(pgConString)
  )

  # Connect to the PostgreSQL notification channels
  @connect: _.once( (pgConString = null) ->
    if Meteor.isServer
      unless pgConString
        Mediator.log "mediator:connect:error"
        Mediator.log "pgConstring undefined"
        return
      # Define PostgreSQL client
      Mediator.client = new pg.Client pgConString
      # Create persistent connection to PostgreSQL
      Mediator.client.connect()
      # postgres notification event handler
      Mediator.client.on "notification", (notification) ->
        # write record to mongo or something
        Mediator.log "mediator:notification:#{notification.channel}"
        notification = Mediator.parse notification
        Mediator.publish notification.channel, notification
      Mediator.client.on 'error', (err) ->
        Mediator.log "mediator:client:error"
        Mediator.log err
  )

  # Listen to the PostgreSQL notification channels defined by channel
  @listen: (channel) ->
    if Meteor.isServer
      Mediator.client.query 'LISTEN "' + channel + '_INSERT"'
      Mediator.client.query 'LISTEN "' + channel + '_UPDATE"'
      Mediator.client.query 'LISTEN "' + channel + '_DELETE"'

  # parse a postgresql notifcation into a mediator notification
  @parse: (notification) ->
    if Meteor.isServer
      notification =
        channel: notification.channel.split('_')[0]
        operation: notification.channel.split('_')[1]
        payload: notification.payload
      Mediator.log notification
      return notification

  # Mediator notification channels
  @channels: {}

  # Create a reactive publication the the specified channel
  @publish: (name) ->
    Mediator.channels[name].args = _.toArray(arguments)
    Mediator.channels[name].deps.changed()

  # Create a reactive subscription for the specified channel
  @subscribe: (name) ->
    unless Mediator.channels[name]
      Mediator.channels[name] =
        deps: new Deps.Dependency
        args: null
    Mediator.channels[name].deps.depend()
    Mediator.channels[name].args