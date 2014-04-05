if( Meteor.isServer ) {
  Tinytest.add('PostgreSQL - defined on server', function (test) {
    test.notEqual( pg, undefined, 'Expected pg to be defined on the server.' );
  });
}


if( Meteor.isClient ) {
  Tinytest.add('PostgreSQL - undefined on client', function (test) {
    pg = pg || undefined;
    test.isUndefined( pg, 'Expected pg to be undefined on the client.' )
  });
}