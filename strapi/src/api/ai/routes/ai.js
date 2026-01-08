module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/ai/generate-seo',
      handler: 'ai.generateSeo',
      config: {
        auth: false,
      },
    },
    {
      method: 'POST',
      path: '/ai/generate-excerpt',
      handler: 'ai.generateExcerpt',
      config: {
        auth: false,
      },
    },
    {
      method: 'POST',
      path: '/ai/generate-image',
      handler: 'ai.generateImage',
      config: {
        auth: false,
      },
    },
    {
      method: 'POST',
      path: '/ai/generate-blog-draft',
      handler: 'ai.generateBlogDraft',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/ai/status',
      handler: 'ai.status',
      config: {
        auth: false,
      },
    },
  ],
};
