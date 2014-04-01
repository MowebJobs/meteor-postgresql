Package.describe({
  summary: "A postgreSQL connector for meteor"
});

Package.on_use(function (api, where) {
  api.use([
    'underscore',
    'coffeescript'
  ], ['client','server']);

  Npm.depends({
    // [Npm Postgres client](https://www.npmjs.org/package/pg)
    pg: '2.11.1'
  });

  api.add_files([
    'postgresql.coffee'
  ], ['server']);

  api.export([
    'pg'
  ], ['server']);
});

Package.on_test(function (api) {
  api.use('postgresql');
});
