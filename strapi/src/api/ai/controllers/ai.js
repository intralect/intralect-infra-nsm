'use strict';

module.exports = {
  async generateSeo(ctx) {
    try {
      const { title, content } = ctx.request.body;
      
      if (!title || !content) {
        return ctx.badRequest('Title and content required');
      }
      
      const gemini = require('../../../services/gemini');
      
      if (!gemini.isConfigured()) {
        return ctx.badRequest('Gemini not configured');
      }
      
      const seo = await gemini.generateSEO(title, content);
      ctx.body = seo;
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  async generateExcerpt(ctx) {
    try {
      const { content, maxLength = 300 } = ctx.request.body;
      
      if (!content) {
        return ctx.badRequest('Content required');
      }
      
      const gemini = require('../../../services/gemini');
      
      if (!gemini.isConfigured()) {
        return ctx.badRequest('Gemini not configured');
      }
      
      const excerpt = await gemini.generateExcerpt(content, maxLength);
      ctx.body = { excerpt };
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  async generateImage(ctx) {
    try {
      const {
        title,
        content,
        brand,
        category,
        collectionType,
        method = 'dalle3' // Default to DALL-E 3 (Gemini Image not available on free tier)
      } = ctx.request.body;

      if (!title) {
        return ctx.badRequest('Title required');
      }

      const gemini = require('../../../services/gemini');

      if (!gemini.isConfigured()) {
        return ctx.badRequest('Gemini not configured');
      }

      // Generate the image prompt (same for both methods)
      const prompt = await gemini.generateImagePrompt(
        title,
        content || '',
        brand || {},
        category || null,
        collectionType || null // Pass collection type for brand-specific settings
      );

      // Choose image generation method
      if (method === 'dalle3') {
        // DALL-E 3 method (original - requires OpenAI API)
        const openai = require('../../../services/openai');

        if (!openai.isConfigured()) {
          return ctx.badRequest('OpenAI not configured for DALL-E 3');
        }

        const imageUrl = await openai.generateImage(prompt, {
          size: '1792x1024',
          quality: 'standard',
          style: 'vivid',
        });

        ctx.body = {
          method: 'dalle3',
          prompt,
          imageUrl,
          message: 'Download and upload to Media Library'
        };
      } else {
        // Gemini native image generation (default - better quality, simpler)
        const imageData = await gemini.generateImageNative(prompt);

        ctx.body = {
          method: 'gemini',
          prompt,
          imageBase64: imageData.base64,
          mimeType: imageData.mimeType,
          message: 'Base64 image ready - convert to blob and upload to Media Library'
        };
      }
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  async generateBlogDraft(ctx) {
    try {
      const { topic, keywords = [], outline = '' } = ctx.request.body;

      if (!topic) {
        return ctx.badRequest('Topic required');
      }

      const gemini = require('../../../services/gemini');

      if (!gemini.isConfigured()) {
        return ctx.badRequest('Gemini not configured');
      }

      const content = await gemini.generateBlogDraft(topic, keywords, outline);
      ctx.body = { content };
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },

  async status(ctx) {
    const gemini = require('../../../services/gemini');
    const openai = require('../../../services/openai');

    ctx.body = {
      gemini: gemini.isConfigured(),
      openai: openai.isConfigured(),
      semanticSearch: process.env.ENABLE_SEMANTIC_SEARCH === 'true',
    };
  },
};
