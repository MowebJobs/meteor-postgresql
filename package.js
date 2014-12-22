Package.describe({
  summary: "A postgreSQL connector for meteor"
});

Package.onUse(function (api, where) {
  Npm.depends({
    // [Npm Postgres client](https://www.npmjs.org/package/pg)
    pg: '4.1.1'
  });

  api.addFiles('postgresql.js', 'server');
  api.export('pg', 'server');
});

Package.onTest(function (api) {
  api.use(['postgresql', 'tinytest', 'test-helpers'], ['client', 'server']);
  api.addFiles('postgresql.test.js', ['client', 'server']);
});
