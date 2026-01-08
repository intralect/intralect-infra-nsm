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
      const { title, content, brand, category, collectionType } = ctx.request.body;

      if (!title) {
        return ctx.badRequest('Title required');
      }

      const gemini = require('../../../services/gemini');
      const openai = require('../../../services/openai');

      if (!gemini.isConfigured() || !openai.isConfigured()) {
        return ctx.badRequest('AI services not configured');
      }

      const prompt = await gemini.generateImagePrompt(
        title,
        content || '',
        brand || {},
        category || null,
        collectionType || null // Pass collection type for brand-specific settings
      );

      const imageUrl = await openai.generateImage(prompt, {
        size: '1792x1024',
        quality: 'standard',
        style: 'vivid',
      });

      ctx.body = {
        prompt,
        imageUrl,
        message: 'Download and upload to Media Library'
      };
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
