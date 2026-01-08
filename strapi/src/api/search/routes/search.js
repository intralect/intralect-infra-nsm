module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/search/semantic',
      handler: 'search.semantic',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/search/status',
      handler: 'search.status',
      config: {
        auth: false,
      },
    },
  ],
};
