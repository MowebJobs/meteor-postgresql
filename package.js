Package.describe({
  summary: "A postgres connector for meteor"
});

Package.on_use(function (api, where) {
  api.use([
    'underscore',
    'coffeescript'
  ],['client','server']);

  // [Npm Postgres client](https://www.npmjs.org/package/pg)
  Npm.depends({pg: '2.11.1'});

  api.add_files([
    'meteor-postgres.coffee'
  ], ['client', 'server']);

  api.export([
    'pg',
    'pgConString',
    'NotificationClient'
  ],['server']);
});

Package.on_test(function (api) {
  api.use('meteor-postgres');

  api.add_files([], ['client', 'server']);
});
