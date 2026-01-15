'use strict';

const linkedinService = require('../../../services/linkedin');

module.exports = {
  /**
   * Get LinkedIn settings
   */
  async getSettings(ctx) {
    try {
      // Get settings from database
      const settings = await strapi.store({
        type: 'plugin',
        name: 'linkedin',
        key: 'settings',
      }).get();

      // If settings exist in DB, update the service
      if (settings?.value) {
        linkedinService.setCredentials(settings.value);
      }

      const credentials = linkedinService.getCredentials();

      ctx.body = {
        ...credentials,
        // Add masked token display for UI feedback
        accessTokenMasked: credentials.accessToken,
      };
    } catch (error) {
      ctx.throw(500, error);
    }
  },

  /**
   * Update LinkedIn settings
   */
  async updateSettings(ctx) {
    try {
      const { clientId, clientSecret, accessToken, organizationId } = ctx.request.body;

      // Get existing settings to preserve values
      const existing = await strapi.store({
        type: 'plugin',
        name: 'linkedin',
        key: 'settings',
      }).get();

      const updatedSettings = {
        clientId: clientId || existing?.value?.clientId,
        clientSecret: clientSecret || existing?.value?.clientSecret,
        accessToken: accessToken || existing?.value?.accessToken,
        organizationId: organizationId || existing?.value?.organizationId,
      };

      // Save to database
      await strapi.store({
        type: 'plugin',
        name: 'linkedin',
        key: 'settings',
      }).set({
        value: updatedSettings,
      });

      // Update service credentials
      linkedinService.setCredentials(updatedSettings);

      ctx.body = {
        success: true,
        message: 'LinkedIn credentials updated successfully',
      };
    } catch (error) {
      ctx.throw(500, error);
    }
  },

  /**
   * Generate LinkedIn post from article
   */
  async generatePost(ctx) {
    try {
      const { title, excerpt, content, articleUrl } = ctx.request.body;

      if (!title || !articleUrl) {
        return ctx.badRequest('Title and article URL are required');
      }

      const postText = await linkedinService.generateLinkedInPost(
        title,
        excerpt || '',
        content || '',
        articleUrl
      );

      ctx.body = {
        success: true,
        postText,
      };
    } catch (error) {
      console.error('Generate post error:', error);
      ctx.throw(500, error);
    }
  },

  /**
   * Publish article to LinkedIn
   */
  async publish(ctx) {
    try {
      const { articleId, postText, articleUrl, imageUrl } = ctx.request.body;

      if (!postText || !articleUrl) {
        return ctx.badRequest('Post text and article URL are required');
      }

      // Post to LinkedIn
      const result = await linkedinService.postToLinkedIn({
        text: postText,
        articleUrl,
        imageUrl,
      });

      // Update article with LinkedIn post info
      if (articleId) {
        await strapi.entityService.update('api::amabex-article.amabex-article', articleId, {
          data: {
            linkedin_posted: true,
            linkedin_post_id: result.postId,
            linkedin_posted_at: new Date(),
          },
        });
      }

      ctx.body = {
        success: true,
        message: 'Successfully posted to LinkedIn',
        postId: result.postId,
      };
    } catch (error) {
      console.error('LinkedIn publish error:', error);
      ctx.throw(500, error.message);
    }
  },

  /**
   * Validate LinkedIn credentials
   */
  async validateCredentials(ctx) {
    try {
      const isValid = await linkedinService.validateCredentials();
      ctx.body = {
        valid: isValid,
        message: isValid ? 'Credentials are valid' : 'Invalid or expired credentials',
      };
    } catch (error) {
      ctx.throw(500, error);
    }
  },

  /**
   * Initiate OAuth 2.0 flow
   */
  async oauthAuthorize(ctx) {
    try {
      // Get client ID from settings
      const settings = await strapi.store({
        type: 'plugin',
        name: 'linkedin',
        key: 'settings',
      }).get();

      const clientId = settings?.value?.clientId || process.env.LINKEDIN_CLIENT_ID;

      if (!clientId) {
        return ctx.badRequest('LinkedIn Client ID not configured');
      }

      // Build authorization URL
      const redirectUri = `${ctx.request.origin}/api/linkedin/oauth/callback`;
      const scope = 'openid profile w_member_social';
      const state = Math.random().toString(36).substring(7); // Random state for CSRF protection

      const authUrl = `https://www.linkedin.com/oauth/v2/authorization?` +
        `response_type=code&` +
        `client_id=${clientId}&` +
        `redirect_uri=${encodeURIComponent(redirectUri)}&` +
        `scope=${encodeURIComponent(scope)}&` +
        `state=${state}`;

      // Store state in session for validation (simple version)
      ctx.session = ctx.session || {};
      ctx.session.linkedinOAuthState = state;

      // Redirect to LinkedIn authorization page
      ctx.redirect(authUrl);
    } catch (error) {
      ctx.throw(500, error);
    }
  },

  /**
   * OAuth callback - exchange code for access token
   */
  async oauthCallback(ctx) {
    try {
      const { code, state, error, error_description } = ctx.query;

      // Check for errors
      if (error) {
        return ctx.send(`
          <!DOCTYPE html>
          <html>
            <head><title>LinkedIn OAuth Error</title></head>
            <body style="font-family: Arial; padding: 40px; text-align: center;">
              <h1 style="color: #d32f2f;">❌ OAuth Error</h1>
              <p><strong>Error:</strong> ${error}</p>
              <p>${error_description || ''}</p>
              <p><a href="/admin">Return to Admin</a></p>
            </body>
          </html>
        `);
      }

      if (!code) {
        return ctx.badRequest('Authorization code not provided');
      }

      // Get settings
      const settings = await strapi.store({
        type: 'plugin',
        name: 'linkedin',
        key: 'settings',
      }).get();

      const clientId = settings?.value?.clientId || process.env.LINKEDIN_CLIENT_ID;
      const clientSecret = settings?.value?.clientSecret || process.env.LINKEDIN_CLIENT_SECRET;

      if (!clientId || !clientSecret) {
        return ctx.send(`
          <!DOCTYPE html>
          <html>
            <head><title>Configuration Error</title></head>
            <body style="font-family: Arial; padding: 40px; text-align: center;">
              <h1 style="color: #d32f2f;">❌ Configuration Error</h1>
              <p>LinkedIn Client ID or Client Secret not configured.</p>
              <p>Please configure them in LinkedIn Settings.</p>
              <p><a href="/admin">Return to Admin</a></p>
            </body>
          </html>
        `);
      }

      const redirectUri = `${ctx.request.origin}/api/linkedin/oauth/callback`;

      // Exchange code for access token
      const axios = require('axios');
      const tokenResponse = await axios.post(
        'https://www.linkedin.com/oauth/v2/accessToken',
        new URLSearchParams({
          grant_type: 'authorization_code',
          code: code,
          redirect_uri: redirectUri,
          client_id: clientId,
          client_secret: clientSecret,
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      const accessToken = tokenResponse.data.access_token;
      const expiresIn = tokenResponse.data.expires_in;

      // Save access token to settings
      await strapi.store({
        type: 'plugin',
        name: 'linkedin',
        key: 'settings',
      }).set({
        value: {
          clientId,
          clientSecret,
          accessToken,
          organizationId: settings?.value?.organizationId,
        },
      });

      // Update service credentials
      linkedinService.setCredentials({ clientId, accessToken });

      // Return success page with token
      ctx.send(`
        <!DOCTYPE html>
        <html>
          <head>
            <title>LinkedIn OAuth Success</title>
            <style>
              body { font-family: Arial; padding: 40px; text-align: center; }
              .success { color: #4caf50; }
              .token-box {
                background: #f5f5f5;
                padding: 20px;
                margin: 20px auto;
                max-width: 600px;
                border-radius: 8px;
                word-break: break-all;
              }
              .copy-btn {
                background: #4285f4;
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 4px;
                cursor: pointer;
                margin: 10px;
              }
            </style>
          </head>
          <body>
            <h1 class="success">✅ LinkedIn Connected Successfully!</h1>
            <p>Your access token has been saved and is ready to use.</p>
            <div class="token-box">
              <strong>Access Token:</strong><br>
              <code id="token">${accessToken}</code>
            </div>
            <p><small>Expires in: ${Math.floor(expiresIn / 86400)} days</small></p>
            <button class="copy-btn" onclick="copyToken()">Copy Token</button>
            <button class="copy-btn" onclick="window.location.href='/admin'">Go to Admin</button>
            <script>
              function copyToken() {
                const token = document.getElementById('token').textContent;
                navigator.clipboard.writeText(token);
                alert('Access token copied to clipboard!');
              }
            </script>
          </body>
        </html>
      `);
    } catch (error) {
      console.error('OAuth callback error:', error);
      ctx.send(`
        <!DOCTYPE html>
        <html>
          <head><title>OAuth Error</title></head>
          <body style="font-family: Arial; padding: 40px; text-align: center;">
            <h1 style="color: #d32f2f;">❌ Token Exchange Failed</h1>
            <p><strong>Error:</strong> ${error.message}</p>
            <p>${error.response?.data?.error_description || ''}</p>
            <p><a href="/admin">Return to Admin</a></p>
          </body>
        </html>
      `);
    }
  },
};
