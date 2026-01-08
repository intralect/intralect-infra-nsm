'use strict';

const openaiService = require('./openai');

module.exports = {
  async search(query, collection, limit = 10) {
    if (!openaiService.isConfigured()) {
      throw new Error('Semantic search requires OpenAI API key');
    }
    
    const queryEmbedding = await openaiService.generateEmbedding(query);
    
    const knex = strapi.db.connection;
    
    const results = await knex.raw(`
      SELECT 
        id,
        title,
        slug,
        excerpt,
        1 - (embedding <=> ?::vector) as similarity
      FROM ${collection}
      WHERE embedding IS NOT NULL
      ORDER BY embedding <=> ?::vector
      LIMIT ?
    `, [JSON.stringify(queryEmbedding), JSON.stringify(queryEmbedding), limit]);
    
    return results.rows;
  },
  
  async indexArticle(article, collection) {
    if (!openaiService.isConfigured()) {
      console.warn('Skipping embedding - OpenAI not configured');
      return;
    }
    
    const textToEmbed = `${article.title} ${article.excerpt || ''} ${article.content || ''}`;
    const embedding = await openaiService.generateEmbedding(textToEmbed);
    
    const knex = strapi.db.connection;
    
    await knex.raw(`
      UPDATE ${collection}
      SET embedding = ?::vector
      WHERE id = ?
    `, [JSON.stringify(embedding), article.id]);
  },
  
  isEnabled() {
    return process.env.ENABLE_SEMANTIC_SEARCH === 'true' && openaiService.isConfigured();
  },
};
