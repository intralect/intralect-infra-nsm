# React Frontend Setup Guide

**Goal:** Display blog articles from Strapi CMS on your React website

## Quick Start

### 1. Install Dependencies

```bash
npm install react-router-dom react-helmet axios
# or
yarn add react-router-dom react-helmet axios
```

### 2. API Configuration

Create `src/config/api.js`:
```javascript
export const API_URL = 'https://cms.yaicos.com/api';
export const STRAPI_URL = 'https://cms.yaicos.com';
```

### 3. API Service

Create `src/services/strapiService.js`:
```javascript
import axios from 'axios';
import { API_URL } from '../config/api';

const api = axios.create({
  baseURL: API_URL,
});

// Get all published articles
export const getArticles = async (page = 1, pageSize = 10) => {
  const response = await api.get('/yaicos-articles', {
    params: {
      'pagination[page]': page,
      'pagination[pageSize]': pageSize,
      populate: '*',
      sort: 'publishedAt:desc',
    },
  });
  return response.data;
};

// Get single article by slug
export const getArticleBySlug = async (slug) => {
  const response = await api.get('/yaicos-articles', {
    params: {
      'filters[slug][$eq]': slug,
      populate: '*',
    },
  });
  return response.data.data[0];
};

// Get articles by category
export const getArticlesByCategory = async (category) => {
  const response = await api.get('/yaicos-articles', {
    params: {
      'filters[category][$eq]': category,
      populate: '*',
    },
  });
  return response.data;
};

// Search articles
export const searchArticles = async (query) => {
  const response = await api.get('/yaicos-articles', {
    params: {
      'filters[title][$containsi]': query,
      populate: '*',
    },
  });
  return response.data;
};

// AI Generation Services
export const generateBlogDraft = async (topic, keywords = [], outline = '') => {
  const response = await api.post('/ai/generate-blog-draft', {
    topic,
    keywords,
    outline,
  });
  return response.data;
};

export const generateSEO = async (title, content) => {
  const response = await api.post('/ai/generate-seo', {
    title,
    content,
  });
  return response.data;
};

export const generateImage = async (title, content) => {
  const response = await api.post('/ai/generate-image', {
    title,
    content,
  });
  return response.data;
};
```

### 4. Routes Setup

In your `src/App.js`:
```javascript
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import BlogList from './pages/BlogList';
import BlogArticle from './pages/BlogArticle';
import BlogCategory from './pages/BlogCategory';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/blog" element={<BlogList />} />
        <Route path="/blog/:slug" element={<BlogArticle />} />
        <Route path="/blog/category/:category" element={<BlogCategory />} />
      </Routes>
    </Router>
  );
}
```

### 5. Blog List Page

Create `src/pages/BlogList.js`:
```javascript
import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { getArticles } from '../services/strapiService';
import { STRAPI_URL } from '../config/api';

const BlogList = () => {
  const [articles, setArticles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);

  useEffect(() => {
    fetchArticles();
  }, [page]);

  const fetchArticles = async () => {
    setLoading(true);
    try {
      const response = await getArticles(page, 10);
      setArticles(response.data);
    } catch (error) {
      console.error('Error fetching articles:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div>Loading articles...</div>;

  return (
    <div className="blog-list">
      <h1>Blog</h1>

      <div className="articles-grid">
        {articles.map((article) => {
          const { attributes } = article;
          const imageUrl = attributes.featured_image?.data?.attributes?.url;

          return (
            <article key={article.id} className="article-card">
              {imageUrl && (
                <Link to={`/blog/${attributes.slug}`}>
                  <img
                    src={`${STRAPI_URL}${imageUrl}`}
                    alt={attributes.title}
                  />
                </Link>
              )}

              <div className="article-content">
                <span className="category">{attributes.category}</span>

                <h2>
                  <Link to={`/blog/${attributes.slug}`}>
                    {attributes.title}
                  </Link>
                </h2>

                <p className="excerpt">{attributes.excerpt}</p>

                <div className="meta">
                  <time>
                    {new Date(attributes.publishedAt).toLocaleDateString()}
                  </time>
                  {attributes.author?.data && (
                    <span className="author">
                      By {attributes.author.data.attributes.name}
                    </span>
                  )}
                </div>

                <Link to={`/blog/${attributes.slug}`} className="read-more">
                  Read More →
                </Link>
              </div>
            </article>
          );
        })}
      </div>

      {/* Pagination */}
      <div className="pagination">
        <button
          onClick={() => setPage(page - 1)}
          disabled={page === 1}
        >
          Previous
        </button>
        <span>Page {page}</span>
        <button onClick={() => setPage(page + 1)}>
          Next
        </button>
      </div>
    </div>
  );
};

export default BlogList;
```

### 6. Single Article Page

Create `src/pages/BlogArticle.js`:
```javascript
import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Helmet } from 'react-helmet';
import { getArticleBySlug } from '../services/strapiService';
import { STRAPI_URL } from '../config/api';

const BlogArticle = () => {
  const { slug } = useParams();
  const [article, setArticle] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchArticle();
  }, [slug]);

  const fetchArticle = async () => {
    setLoading(true);
    try {
      const data = await getArticleBySlug(slug);
      setArticle(data);
    } catch (error) {
      console.error('Error fetching article:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <div>Loading article...</div>;
  if (!article) return <div>Article not found</div>;

  const { attributes } = article;
  const imageUrl = attributes.featured_image?.data?.attributes?.url;
  const ogImageUrl = attributes.og_image?.data?.attributes?.url || imageUrl;

  return (
    <>
      {/* SEO Meta Tags */}
      <Helmet>
        <title>{attributes.meta_title || attributes.title}</title>
        <meta name="description" content={attributes.meta_description} />

        {/* Open Graph */}
        <meta property="og:title" content={attributes.meta_title || attributes.title} />
        <meta property="og:description" content={attributes.meta_description} />
        {ogImageUrl && (
          <meta property="og:image" content={`${STRAPI_URL}${ogImageUrl}`} />
        )}
        <meta property="og:type" content="article" />

        {/* Twitter Card */}
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:title" content={attributes.meta_title || attributes.title} />
        <meta name="twitter:description" content={attributes.meta_description} />

        {/* Canonical */}
        {attributes.canonical_url && (
          <link rel="canonical" href={attributes.canonical_url} />
        )}

        {/* No Index */}
        {attributes.no_index && <meta name="robots" content="noindex" />}
      </Helmet>

      <article className="blog-article">
        {/* Breadcrumbs */}
        <nav className="breadcrumbs">
          <Link to="/">Home</Link> /
          <Link to="/blog">Blog</Link> /
          <span>{attributes.title}</span>
        </nav>

        {/* Header */}
        <header>
          <span className="category">{attributes.category}</span>
          <h1>{attributes.title}</h1>

          {attributes.excerpt && (
            <p className="lead">{attributes.excerpt}</p>
          )}

          <div className="meta">
            {attributes.author?.data && (
              <div className="author">
                {attributes.author.data.attributes.avatar?.data && (
                  <img
                    src={`${STRAPI_URL}${attributes.author.data.attributes.avatar.data.attributes.url}`}
                    alt={attributes.author.data.attributes.name}
                  />
                )}
                <div>
                  <strong>{attributes.author.data.attributes.name}</strong>
                  {attributes.author.data.attributes.bio && (
                    <p>{attributes.author.data.attributes.bio}</p>
                  )}
                </div>
              </div>
            )}

            <time>
              Published {new Date(attributes.publishedAt).toLocaleDateString()}
            </time>
          </div>

          {imageUrl && (
            <img
              src={`${STRAPI_URL}${imageUrl}`}
              alt={attributes.title}
              className="featured-image"
            />
          )}
        </header>

        {/* Content */}
        <div
          className="article-content"
          dangerouslySetInnerHTML={{ __html: attributes.content }}
        />

        {/* Share Buttons */}
        <div className="share-buttons">
          <h3>Share this article</h3>
          <a
            href={`https://twitter.com/intent/tweet?url=${window.location.href}&text=${attributes.title}`}
            target="_blank"
            rel="noopener noreferrer"
          >
            Twitter
          </a>
          <a
            href={`https://www.facebook.com/sharer/sharer.php?u=${window.location.href}`}
            target="_blank"
            rel="noopener noreferrer"
          >
            Facebook
          </a>
          <a
            href={`https://www.linkedin.com/sharing/share-offsite/?url=${window.location.href}`}
            target="_blank"
            rel="noopener noreferrer"
          >
            LinkedIn
          </a>
        </div>
      </article>
    </>
  );
};

export default BlogArticle;
```

### 7. Basic CSS

Create `src/styles/blog.css`:
```css
.blog-list {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.articles-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 2rem;
  margin: 2rem 0;
}

.article-card {
  border: 1px solid #eee;
  border-radius: 8px;
  overflow: hidden;
  transition: transform 0.2s;
}

.article-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.article-card img {
  width: 100%;
  height: 200px;
  object-fit: cover;
}

.article-content {
  padding: 1.5rem;
}

.category {
  display: inline-block;
  background: #007bff;
  color: white;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  font-size: 0.875rem;
  margin-bottom: 0.5rem;
}

.excerpt {
  color: #666;
  margin: 1rem 0;
}

.meta {
  display: flex;
  justify-content: space-between;
  font-size: 0.875rem;
  color: #888;
  margin: 1rem 0;
}

.read-more {
  color: #007bff;
  text-decoration: none;
  font-weight: 600;
}

.blog-article {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
}

.blog-article .featured-image {
  width: 100%;
  height: auto;
  border-radius: 8px;
  margin: 2rem 0;
}

.article-content {
  line-height: 1.8;
  font-size: 1.125rem;
}

.article-content h2 {
  margin-top: 2rem;
  margin-bottom: 1rem;
}

.article-content p {
  margin-bottom: 1.5rem;
}

.share-buttons {
  margin-top: 3rem;
  padding-top: 2rem;
  border-top: 1px solid #eee;
}

.share-buttons a {
  display: inline-block;
  margin-right: 1rem;
  padding: 0.5rem 1rem;
  background: #007bff;
  color: white;
  text-decoration: none;
  border-radius: 4px;
}
```

## Next Steps

### 1. Test the API Connection
```javascript
// In your browser console
fetch('https://cms.yaicos.com/api/yaicos-articles?populate=*')
  .then(res => res.json())
  .then(data => console.log(data));
```

### 2. Handle Markdown Content
If articles use markdown, install:
```bash
npm install marked
```

Then in your component:
```javascript
import { marked } from 'marked';

// Convert markdown to HTML
const htmlContent = marked(attributes.content);
```

### 3. Add Loading States
Use a loading spinner component for better UX.

### 4. Error Handling
Add try-catch blocks and error messages for failed API calls.

### 5. Image Optimization
Consider using lazy loading and responsive images.

## Additional Features to Add

- Search functionality
- Category filters
- Related articles
- Comments section (using Strapi plugin)
- Newsletter signup
- Table of contents for long articles
- Reading time estimate
- Social share count

## Resources

- **Strapi Docs:** https://docs.strapi.io/
- **React Router:** https://reactrouter.com/
- **React Helmet:** https://github.com/nfl/react-helmet

---

**Ready to build!** All APIs are working and ready to use.
