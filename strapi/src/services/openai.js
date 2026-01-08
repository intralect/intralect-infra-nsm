'use strict';

const OpenAI = require('openai');

let openaiClient = null;

const getClient = () => {
  if (!openaiClient && process.env.OPENAI_API_KEY) {
    openaiClient = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }
  return openaiClient;
};

module.exports = {
  async generateImage(prompt, options = {}) {
    const client = getClient();
    if (!client) throw new Error('OpenAI not configured');
    
    const { size = '1792x1024', quality = 'standard', style = 'vivid' } = options;
    
    try {
      const response = await client.images.generate({
        model: 'dall-e-3',
        prompt: prompt,
        n: 1,
        size: size,
        quality: quality,
        style: style,
      });
      
      return response.data[0].url;
    } catch (error) {
      console.error('DALL-E Error:', error.message);
      throw error;
    }
  },
  
  async generateEmbedding(text) {
    const client = getClient();
    if (!client) throw new Error('OpenAI not configured');
    
    try {
      const response = await client.embeddings.create({
        model: 'text-embedding-3-small',
        input: text,
        encoding_format: 'float',
      });
      
      return response.data[0].embedding;
    } catch (error) {
      console.error('Embedding Error:', error.message);
      throw error;
    }
  },
  
  isConfigured() {
    return !!process.env.OPENAI_API_KEY;
  },
};
