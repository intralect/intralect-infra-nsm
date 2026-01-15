'use strict';

module.exports = {
  routes: [
    {
      method: 'GET',
      path: '/linkedin/settings',
      handler: 'linkedin.getSettings',
      config: {
        auth: false,
      },
    },
    {
      method: 'POST',
      path: '/linkedin/settings',
      handler: 'linkedin.updateSettings',
      config: {
        auth: false,
      },
    },
    {
      method: 'POST',
      path: '/linkedin/generate-post',
      handler: 'linkedin.generatePost',
      config: {
        auth: false,
      },
    },
    {
      method: 'POST',
      path: '/linkedin/publish',
      handler: 'linkedin.publish',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/linkedin/validate',
      handler: 'linkedin.validateCredentials',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/linkedin/oauth/callback',
      handler: 'linkedin.oauthCallback',
      config: {
        auth: false,
      },
    },
    {
      method: 'GET',
      path: '/linkedin/oauth/authorize',
      handler: 'linkedin.oauthAuthorize',
      config: {
        auth: false,
      },
    },
  ],
};
