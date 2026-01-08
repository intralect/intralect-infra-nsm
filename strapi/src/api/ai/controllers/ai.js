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
        method = 'gemini' // Default to Gemini 2.5 Flash Image (paid plan enabled)
      } = ctx.request.body;

      if (!title) {
        return ctx.badRequest('Title required');
      }

      const gemini = require('../../../services/gemini');

      if (!gemini.isConfigured()) {
        return ctx.badRequest('Gemini not configured');
      }

      // Generate the image prompt with fallback
      let prompt;
      let promptFallback = false;

      try {
        // Try to generate detailed prompt with Gemini
        prompt = await gemini.generateImagePrompt(
          title,
          content || '',
          brand || {},
          category || null,
          collectionType || null
        );
      } catch (promptError) {
        // If Gemini text model is overloaded, use simple fallback prompt
        console.warn('Gemini prompt generation failed, using fallback prompt:', promptError.message.substring(0, 100));
        promptFallback = true;

        // Create a simple but effective prompt based on collection type
        const collectionPrompts = {
          'yaicos-article': `Professional documentary photograph for international education blog titled "${title}". Show diverse young international students aged 18-30 from various ethnicities (Asian, African, European, Latin American, Middle Eastern) engaged in authentic educational activities. Captured with Canon EOS R5, 35mm f/2.8 lens, natural lighting, golden hour warmth. Real humans in genuine candid moments, shot from behind or at angles (no direct face shots). Modern, welcoming, aspirational atmosphere. Bright blues, warm oranges, natural daylight. Wide landscape format 1792x1024. Documentary/photojournalism style like National Geographic. STRICTLY: Professional DSLR photography only - NO cartoon, illustration, 3D render, CGI, or animated style.`,

          'guardscan-article': `Professional technical photograph for cybersecurity blog titled "${title}". High-tech security visualization with deep blues, cyber green, electric blue accents on dark background. Advanced network security, encryption visualization, threat detection systems. Sophisticated enterprise-grade security aesthetic similar to CrowdStrike or Palo Alto Networks. Shot on professional camera, dramatic lighting. Wide landscape 1792x1024. NO faces, hands, text, or logos. Technical and cutting-edge style.`,

          'amabex-article': `Professional corporate photograph for business procurement blog titled "${title}". Clean, systematic corporate aesthetic with corporate blues, silver/gray accents, white space. Abstract representation of supply chains, business networks, procurement processes. Fortune 500 company style, trustworthy and professional. Shot on professional camera. Wide landscape 1792x1024. NO faces, hands, text, or informal elements.`
        };

        prompt = collectionPrompts[collectionType] || `Professional photograph for blog article titled "${title}". Modern, clean, professional aesthetic. Wide landscape format 1792x1024. High quality DSLR photography. NO text, logos, or cluttered elements.`;
      }

      let usedMethod = method;
      let fallbackUsed = false;

      // Choose image generation method with automatic fallback
      if (method === 'dalle3') {
        // DALL-E 3 method (explicit request)
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
          promptFallback,
          message: promptFallback ? 'Gemini text model was overloaded - used simple prompt. Download and upload to Media Library' : 'Download and upload to Media Library'
        };
      } else {
        // Try Gemini first, fallback to DALL-E 3 if it fails
        try {
          console.log('Attempting Gemini image generation...');
          const imageData = await gemini.generateImageNative(prompt);

          ctx.body = {
            method: 'gemini',
            prompt,
            imageBase64: imageData.base64,
            mimeType: imageData.mimeType,
            promptFallback,
            message: promptFallback ? 'Gemini text model was overloaded - used simple prompt. Base64 image ready - convert to blob and upload to Media Library' : 'Base64 image ready - convert to blob and upload to Media Library'
          };
        } catch (geminiError) {
          // Check if it's a recoverable error (503, 429, timeout, etc.)
          const errorMsg = geminiError.message || '';
          const isRecoverable =
            errorMsg.includes('503') ||
            errorMsg.includes('overloaded') ||
            errorMsg.includes('429') ||
            errorMsg.includes('quota') ||
            errorMsg.includes('timeout');

          if (isRecoverable) {
            console.warn('Gemini failed (overloaded/quota), falling back to DALL-E 3:', errorMsg.substring(0, 100));

            // Fallback to DALL-E 3
            const openai = require('../../../services/openai');

            if (!openai.isConfigured()) {
              throw new Error('Gemini overloaded and OpenAI not configured. Cannot generate image.');
            }

            const imageUrl = await openai.generateImage(prompt, {
              size: '1792x1024',
              quality: 'standard',
              style: 'vivid',
            });

            usedMethod = 'dalle3';
            fallbackUsed = true;

            ctx.body = {
              method: 'dalle3',
              fallback: true,
              originalError: 'Gemini image generation overloaded',
              prompt,
              imageUrl,
              promptFallback,
              message: promptFallback
                ? 'Both Gemini services were overloaded - used simple prompt + DALL-E 3. Download and upload to Media Library'
                : 'Gemini image generation was overloaded - used DALL-E 3 fallback. Download and upload to Media Library'
            };
          } else {
            // Non-recoverable error, throw it
            throw geminiError;
          }
        }
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
