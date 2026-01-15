'use strict';

const axios = require('axios');

/**
 * LinkedIn API Service
 * Handles posting articles to LinkedIn using the LinkedIn API v2
 */

// Store credentials (will be moved to database settings)
let linkedInConfig = {
  clientId: null,
  accessToken: null,
  organizationId: null // For company pages
};

// Initialize from environment variables if available
if (process.env.LINKEDIN_CLIENT_ID) {
  linkedInConfig.clientId = process.env.LINKEDIN_CLIENT_ID;
}
if (process.env.LINKEDIN_ACCESS_TOKEN) {
  linkedInConfig.accessToken = process.env.LINKEDIN_ACCESS_TOKEN;
}
if (process.env.LINKEDIN_ORGANIZATION_ID) {
  linkedInConfig.organizationId = process.env.LINKEDIN_ORGANIZATION_ID;
}

module.exports = {
  /**
   * Set LinkedIn credentials
   * @param {Object} config - { clientId, accessToken, organizationId }
   */
  setCredentials(config) {
    if (config.clientId) linkedInConfig.clientId = config.clientId;
    if (config.accessToken) linkedInConfig.accessToken = config.accessToken;
    if (config.organizationId) linkedInConfig.organizationId = config.organizationId;
  },

  /**
   * Get current credentials (for settings display)
   */
  getCredentials() {
    return {
      clientId: linkedInConfig.clientId,
      accessToken: linkedInConfig.accessToken ? '***' + linkedInConfig.accessToken.slice(-4) : null,
      organizationId: linkedInConfig.organizationId,
      isConfigured: !!(linkedInConfig.accessToken && linkedInConfig.clientId)
    };
  },

  /**
   * Generate LinkedIn post content using AI
   * Uses the "Option C" tone: Professional but Approachable
   * @param {String} title - Article title
   * @param {String} excerpt - Article excerpt
   * @param {String} content - Full article content
   * @param {String} articleUrl - URL to the full article
   * @returns {String} LinkedIn post text with emojis and CTA
   */
  async generateLinkedInPost(title, excerpt, content, articleUrl) {
    const gemini = require('./gemini');

    // Use the "Magic Sauce" Formula: Counter-Intuitive Hook → Villain → Financial Translation → Binary Choice
    const prompt = `You are a LinkedIn content expert for Ambaex, a B2B sourcing and manufacturing consultancy serving CFOs and Chief Procurement Officers.

Create a LinkedIn post for this article using the **"Magic Sauce" Formula** that converts executives:

Article Title: ${title}
Article Excerpt: ${excerpt}
Article Content: ${content.substring(0, 1200)}
Full Article URL: ${articleUrl}

CRITICAL: Use the 4-Step "Magic Sauce" Formula:

**STEP 1: Counter-Intuitive Hook (El Gancho)** 🎣
- Challenge a popular belief in procurement/sourcing
- DON'T start with boring facts ("Sourcing is important")
- DO start with "Everyone thinks [X], but actually [opposite]"
- Example: "AI can find a supplier in seconds. But it can't tell you if their factory floor is empty. 📉"

**STEP 2: The Villain (El Enemigo)** 👿
- Identify the SITUATION causing pain (never a person)
- Make the CFO/CPO nod and say "Yes, I hate that too"
- Examples: "Data Overload", "Digital Projections without Reality Checks", "Hidden Supply Chain Risks"
- Connect to current events: COVID, tariffs, AI disruption, geopolitical risks

**STEP 3: Financial Translation (El Dinero)** 💰
- DON'T describe Ambaex services as tasks ("we perform audits", "we visit factories")
- DO translate to money saved/protected
- Example: "We stop you from betting your Q3 margins on a digital projection"
- Speak to the WALLET, not the To-Do list

**STEP 4: Binary Choice Question (La Pregunta)** ⚖️
- End with a strategic question that offers TWO clear choices
- DON'T ask vague "What do you think?"
- DO ask "A vs B?" to boost engagement
- Example: "Are you prioritizing Efficiency (faster AI sourcing) or Resilience (verified supply chains)?"

**FORMAT:**
Headline: [Counter-intuitive hook with 1 emoji]

Body:
[2-3 short paragraphs:
- Paragraph 1: Set up the villain + current market context
- Paragraph 2: How Ambaex solves this (financial translation)
- Paragraph 3: CTA to article]

Read our full analysis: 👉 ${articleUrl}

❓ Strategic Question:
[Binary choice question for comments]

#Procurement #SupplyChainRisk #SouthernEurope #Ambaex #SourcingStrategy

**TONE RULES:**
- Professional but Approachable (Option C)
- Use 2-4 emojis TOTAL (🏭 📊 💼 🔍 📉 ⚙️ 👉 ❓)
- Bold key phrases for scannability
- Short paragraphs (2-3 sentences max)
- Speak to CFO consequences, not procurement processes

Return ONLY the formatted LinkedIn post, ready to copy/paste.`;

    try {
      const postText = await gemini.generateContent(prompt);
      return postText.trim();
    } catch (error) {
      console.error('LinkedIn post generation error:', error);
      // Fallback template if AI fails
      return `${title}\n\n${excerpt}\n\nRead more: ${articleUrl}`;
    }
  },

  /**
   * Post to LinkedIn
   * @param {Object} postData - { text, articleUrl, imageUrl }
   * @returns {Object} LinkedIn API response
   */
  async postToLinkedIn(postData) {
    const { text, articleUrl, imageUrl } = postData;

    if (!linkedInConfig.accessToken) {
      throw new Error('LinkedIn access token not configured');
    }

    try {
      // Get user's LinkedIn profile info using OpenID Connect userinfo endpoint
      const profileResponse = await axios.get('https://api.linkedin.com/v2/userinfo', {
        headers: {
          'Authorization': `Bearer ${linkedInConfig.accessToken}`
        }
      });

      // OpenID returns 'sub' as the person identifier, convert to URN format
      const personUrn = `urn:li:person:${profileResponse.data.sub}`;

      // Prepare the post payload according to LinkedIn official docs
      const payload = {
        author: personUrn,
        lifecycleState: 'PUBLISHED',
        specificContent: {
          'com.linkedin.ugc.ShareContent': {
            shareCommentary: {
              text: text
            },
            shareMediaCategory: 'NONE' // Start with text-only
          }
        },
        visibility: {
          'com.linkedin.ugc.MemberNetworkVisibility': 'PUBLIC'
        }
      };

      // Add article link - LinkedIn will automatically scrape og_image from the URL
      if (articleUrl) {
        payload.specificContent['com.linkedin.ugc.ShareContent'].shareMediaCategory = 'ARTICLE';
        payload.specificContent['com.linkedin.ugc.ShareContent'].media = [{
          status: 'READY',
          originalUrl: articleUrl,
          title: {
            text: text.split('\n')[0].substring(0, 200) // First line as title (max 200 chars)
          },
          description: {
            text: text.substring(0, 256) // Description (max 256 chars)
          }
        }];
      }

      // Post to LinkedIn
      const response = await axios.post(
        'https://api.linkedin.com/v2/ugcPosts',
        payload,
        {
          headers: {
            'Authorization': `Bearer ${linkedInConfig.accessToken}`,
            'Content-Type': 'application/json',
            'X-Restli-Protocol-Version': '2.0.0'
          }
        }
      );

      return {
        success: true,
        postId: response.data.id,
        response: response.data
      };
    } catch (error) {
      console.error('LinkedIn API Error:', error.response?.data || error.message);
      throw new Error(
        `LinkedIn posting failed: ${error.response?.data?.message || error.message}`
      );
    }
  },

  /**
   * Validate LinkedIn credentials
   * @returns {Boolean} True if credentials are valid
   */
  async validateCredentials() {
    if (!linkedInConfig.accessToken) {
      return false;
    }

    try {
      await axios.get('https://api.linkedin.com/v2/userinfo', {
        headers: {
          'Authorization': `Bearer ${linkedInConfig.accessToken}`
        }
      });
      return true;
    } catch (error) {
      console.error('LinkedIn credential validation failed:', error.message);
      return false;
    }
  }
};
