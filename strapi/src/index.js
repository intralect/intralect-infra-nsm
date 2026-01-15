'use strict';

module.exports = {
  /**
   * An asynchronous register function that runs before
   * your application is initialized.
   *
   * This gives you an opportunity to extend code.
   */
  register(/*{ strapi }*/) {},

  /**
   * An asynchronous bootstrap function that runs before
   * your application gets started.
   *
   * This gives you an opportunity to set up your data model,
   * run jobs, or perform some special logic.
   */
  async bootstrap({ strapi }) {
    // Initialize LinkedIn credentials
    const linkedinService = require('./services/linkedin');

    // Load credentials from Strapi store
    const settings = await strapi.store({
      type: 'plugin',
      name: 'linkedin',
      key: 'settings',
    }).get();

    // If settings exist in DB, update the service
    if (settings?.value) {
      linkedinService.setCredentials(settings.value);
      strapi.log.info('LinkedIn credentials loaded from database');
    } else if (process.env.LINKEDIN_CLIENT_ID && process.env.LINKEDIN_ACCESS_TOKEN) {
      // Initialize from environment variables if not in DB
      const credentials = {
        clientId: process.env.LINKEDIN_CLIENT_ID,
        accessToken: process.env.LINKEDIN_ACCESS_TOKEN,
        organizationId: process.env.LINKEDIN_ORGANIZATION_ID,
      };

      // Save to database
      await strapi.store({
        type: 'plugin',
        name: 'linkedin',
        key: 'settings',
      }).set({
        value: credentials,
      });

      linkedinService.setCredentials(credentials);
      strapi.log.info('LinkedIn credentials initialized from environment variables');
    }
  },
};
