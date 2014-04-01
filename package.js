Package.describe({
  summary: "A postgres connector for meteor"
});

Package.on_use(function (api, where) {
  api.use([
    'underscore',
    'coffeescript'
  ], ['client','server']);

  Npm.depends({
    // [Npm Postgres client](https://www.npmjs.org/package/pg)
    pg: '2.11.1',
    // [SQL ORM based on Backbone](http://bookshelfjs.org)
    bookshelf: '0.6.8'
  });

  api.add_files([
    'postgres.coffee',
    'model.coffee',
    'mediator.coffee',
  ], ['client','server']);

  api.export([
    // TODO : i dont want to export pg or pgConstring
    'pg',
    'Bookshelf'
  ], ['server']);

  api.export([
    'Mediator',
    'Model'
  ], ['client','server']);
});

Package.on_test(function (api) {
  api.use('meteor-postgres');
  api.add_files([], ['client', 'server']);
});
