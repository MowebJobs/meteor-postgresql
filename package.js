Package.describe({
  summary: "REPLACEME - What does this package (or the original one you're wrapping) do?"
});

Package.on_use(function (api, where) {
  api.add_files('meteor-postgres.js', ['client', 'server']);
});

Package.on_test(function (api) {
  api.use('meteor-postgres');

  api.add_files('meteor-postgres_tests.js', ['client', 'server']);
});
