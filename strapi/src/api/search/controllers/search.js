'use strict';

module.exports = {
  async semantic(ctx) {
    try {
      const { query, collection = 'guardscan_articles', limit = 10 } = ctx.request.body;
      
      if (!query) {
        return ctx.badRequest('Query required');
      }
      
      const semanticSearch = require('../../../services/semantic-search');
      
      if (!semanticSearch.isEnabled()) {
        return ctx.badRequest('Semantic search not enabled');
      }
      
      const results = await semanticSearch.search(query, collection, limit);
      ctx.body = { results };
    } catch (error) {
      ctx.throw(500, error.message);
    }
  },
  
  async status(ctx) {
    const semanticSearch = require('../../../services/semantic-search');
    
    ctx.body = {
      enabled: semanticSearch.isEnabled(),
    };
  },
};
