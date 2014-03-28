Package.describe({
  summary: "A postgres connector for meteor"
});

Package.on_use(function (api, where) {
  api.use([
    'coffeescript'
  ],['client','server']);

  api.add_files([], ['client', 'server']);
});

Package.on_test(function (api) {
  api.use('meteor-postgres');

  api.add_files([], ['client', 'server']);
});
