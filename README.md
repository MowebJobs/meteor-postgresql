# Meteor PostgreSQL Connector

This package merely wraps the extremely well written and maintained npm package `pg` by [brianc](https://github.com/brianc)

## [pg Docs](https://github.com/brianc/node-postgres)

### Meteorite Installation
`$ mrt add postgresql`

### Example App
`$ cd example && meteor`

## Usage

### Connecting
This package exports `pg` to the server.

`pg` must be initialized with your PostgreSQL connection information.

An example connection that queries the db and then disconnects is provided below.

```coffeescript
pg.connect "postgres://localhost/db", (err, client, done) ->
  console.log "select:start"
  select = client.query
    name: "db:select"
    text: "SELECT * FROM some_table"
  select.on 'row', (row, result) ->
    console.log "select:row"
    console.log row
    console.log result
  select.on 'error', (err) ->
    console.log "select:error"
    console.log err
  select.on 'end', (result) ->
    console.log "select:end"
    console.log result
  )
  done()
```

### Listening to PostgreSQL notifications
In order to listen to notifications you must first have notification triggers setup on your PostgreSQL table.

I reactively publish and subscribe to PostgreSQL notifications using a Mediator class [like this one](https://github.com/lumapictures/module-mediator)

If you already have a PostgreSQL Trigger firing notification then you just need to create a persistent `pg` client and listen on that channel.

```coffeescript
    # Create persistent connection to PostgreSQL
    client = new pg.Client
    client.connect()
    # postgres notification event handler
    client.on "postgres://localhost/austin", (notification) ->
        # write record to MongoDB or something
        console.log "notification:#{notification.channel}"
        console.log notification
    client.on 'error', (err) ->
        console.log "client:error"
        console.log err
```

Here is a trigger pattern that works for me :

#### PostgreSQL Trigger
```sql
-- Trigger: watched_table on users
-- DROP TRIGGER watched_table ON users;

CREATE TRIGGER watched_table
  AFTER INSERT OR UPDATE OR DELETE
  ON users
  FOR EACH ROW
  EXECUTE PROCEDURE notify_trigger();
```

#### PostgreSQL Trigger Function
```sql
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
  OWNER TO austin;
```
