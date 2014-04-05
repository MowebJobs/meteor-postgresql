Package.describe({
  summary: "A postgreSQL connector for meteor"
});

Package.on_use(function (api, where) {
  Npm.depends({
    // [Npm Postgres client](https://www.npmjs.org/package/pg)
    pg: '2.11.1'
  });

  api.add_files([
    'postgresql.js'
  ], ['server']);

  api.export([
    'pg'
  ], ['server']);
});

Package.on_test(function (api) {
  api.use(['postgresql', 'tinytest', 'test-helpers'], ['client', 'server']);
  api.add_files('postgresql.test.js', ['client', 'server']);
});
