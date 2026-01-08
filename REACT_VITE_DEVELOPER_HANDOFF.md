# React Vite Developer Handoff - Blog API Integration

**Purpose:** Quick reference for integrating the blog API into a React Vite application

**API Base URL:** `https://cms.yaicos.com/api`

---

## 1. Available Blog Collections

Three separate blog content types with identical structures:

1. **Yaicos Articles** - `/yaicos-articles`
2. **GuardScan Articles** - `/guardscan-articles`
3. **Amabex Articles** - `/amabex-articles`

---

## 2. Article Schema

Each article contains:

```javascript
{
  id: 1,
  attributes: {
    title: "Article Title",
    slug: "article-title",
    content: "<p>HTML content here...</p>",
    excerpt: "Short summary of the article",
    category: "technology", // One of 20+ categories per collection
    meta_title: "SEO Meta Title",
    meta_description: "SEO Meta Description",
    featured_image: {
      data: {
        id: 1,
        attributes: {
          url: "/uploads/image.png",
          alternativeText: "Image description",
          width: 1792,
          height: 1024
        }
      }
    },
    author: {
      data: {
        id: 1,
        attributes: {
          name: "Author Name",
          email: "author@example.com"
        }
      }
    },
    publishedAt: "2025-01-07T10:30:00.000Z",
    createdAt: "2025-01-07T10:00:00.000Z",
    updatedAt: "2025-01-07T10:30:00.000Z"
  }
}
```

---

## 3. API Endpoints

### Get All Articles (Paginated)

```
GET /api/yaicos-articles?populate=*&pagination[page]=1&pagination[pageSize]=10
```

**Query Parameters:**
- `populate=*` - Include all relations (featured_image, author, etc.)
- `pagination[page]=1` - Page number (default: 1)
- `pagination[pageSize]=10` - Items per page (default: 25)
- `sort=publishedAt:desc` - Sort by field (add `:desc` for descending)
- `filters[category][$eq]=technology` - Filter by category
- `publicationState=live` - Only published articles (default)

**Response:**
```javascript
{
  data: [ /* array of articles */ ],
  meta: {
    pagination: {
      page: 1,
      pageSize: 10,
      pageCount: 5,
      total: 42
    }
  }
}
```

---

### Get Single Article by ID

```
GET /api/yaicos-articles/1?populate=*
```

---

### Get Single Article by Slug

```
GET /api/yaicos-articles?filters[slug][$eq]=article-slug&populate=*
```

This returns an array with one item. Access the article with `data[0]`.

---

### Filter by Category

```
GET /api/yaicos-articles?filters[category][$eq]=technology&populate=*
```

---

### Search by Title

```
GET /api/yaicos-articles?filters[title][$containsi]=search+term&populate=*
```

---

### Get Recent Articles

```
GET /api/yaicos-articles?sort=publishedAt:desc&pagination[pageSize]=5&populate=*
```

---

## 4. Available Categories

### Yaicos Articles (24 categories)
`technology`, `business`, `marketing`, `automation`, `ai-machine-learning`, `cybersecurity`, `cloud-computing`, `data-analytics`, `education`, `career-development`, `international-students`, `study-abroad`, `scholarships`, `visa-immigration`, `student-life`, `language-learning`, `university-guides`, `work-opportunities`, `cultural-adaptation`, `finance-budgeting`, `health-wellness`, `travel`, `networking`, `success-stories`

### GuardScan Articles (20 categories)
`cybersecurity`, `vulnerability-scanning`, `penetration-testing`, `compliance`, `threat-intelligence`, `network-security`, `application-security`, `cloud-security`, `data-protection`, `incident-response`, `security-best-practices`, `malware-analysis`, `zero-day-vulnerabilities`, `encryption`, `authentication`, `firewall-ids-ips`, `security-audits`, `risk-management`, `security-awareness`, `case-studies`

### Amabex Articles (20 categories)
`products`, `services`, `business-solutions`, `technology`, `innovation`, `procurement`, `supply-chain`, `automation`, `ai-integration`, `cost-optimization`, `vendor-management`, `contract-management`, `purchasing-strategies`, `sustainability`, `compliance`, `case-studies`, `industry-insights`, `digital-transformation`, `roi-metrics`, `best-practices`

---

## 5. React Code Examples

### Setup Environment Variables

Create `.env` file:

```bash
VITE_API_URL=https://cms.yaicos.com/api
VITE_MEDIA_URL=https://cms.yaicos.com
```

---

### Fetch Articles Hook

```javascript
// hooks/useArticles.js
import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL;

export function useArticles(collection = 'yaicos-articles', options = {}) {
  const [articles, setArticles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [pagination, setPagination] = useState(null);

  const {
    page = 1,
    pageSize = 10,
    category = null,
    sort = 'publishedAt:desc'
  } = options;

  useEffect(() => {
    const fetchArticles = async () => {
      try {
        setLoading(true);

        const params = new URLSearchParams({
          'populate': '*',
          'pagination[page]': page,
          'pagination[pageSize]': pageSize,
          'sort': sort
        });

        if (category) {
          params.append('filters[category][$eq]', category);
        }

        const response = await fetch(`${API_URL}/${collection}?${params}`);

        if (!response.ok) {
          throw new Error('Failed to fetch articles');
        }

        const data = await response.json();
        setArticles(data.data);
        setPagination(data.meta.pagination);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchArticles();
  }, [collection, page, pageSize, category, sort]);

  return { articles, loading, error, pagination };
}
```

---

### Fetch Single Article by Slug

```javascript
// hooks/useArticleBySlug.js
import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL;

export function useArticleBySlug(collection, slug) {
  const [article, setArticle] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!slug) return;

    const fetchArticle = async () => {
      try {
        setLoading(true);

        const params = new URLSearchParams({
          'populate': '*',
          'filters[slug][$eq]': slug
        });

        const response = await fetch(`${API_URL}/${collection}?${params}`);

        if (!response.ok) {
          throw new Error('Failed to fetch article');
        }

        const data = await response.json();

        if (data.data.length === 0) {
          throw new Error('Article not found');
        }

        setArticle(data.data[0]);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchArticle();
  }, [collection, slug]);

  return { article, loading, error };
}
```

---

### Article List Component Example

```javascript
// components/ArticleList.jsx
import { useArticles } from '../hooks/useArticles';

const MEDIA_URL = import.meta.env.VITE_MEDIA_URL;

export function ArticleList({ collection = 'yaicos-articles', category = null }) {
  const { articles, loading, error, pagination } = useArticles(collection, {
    page: 1,
    pageSize: 10,
    category
  });

  if (loading) return <div>Loading articles...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div className="article-list">
      {articles.map((article) => {
        const { title, slug, excerpt, category, featured_image, publishedAt } = article.attributes;
        const imageUrl = featured_image?.data?.attributes?.url
          ? `${MEDIA_URL}${featured_image.data.attributes.url}`
          : null;

        return (
          <article key={article.id} className="article-card">
            {imageUrl && (
              <img
                src={imageUrl}
                alt={featured_image.data.attributes.alternativeText || title}
                loading="lazy"
              />
            )}
            <div className="article-content">
              <span className="category">{category}</span>
              <h2>{title}</h2>
              <p>{excerpt}</p>
              <time>{new Date(publishedAt).toLocaleDateString()}</time>
              <a href={`/articles/${slug}`}>Read More →</a>
            </div>
          </article>
        );
      })}

      {/* Pagination */}
      {pagination && (
        <div className="pagination">
          <span>Page {pagination.page} of {pagination.pageCount}</span>
          <span>Total: {pagination.total} articles</span>
        </div>
      )}
    </div>
  );
}
```

---

### Single Article Page Example

```javascript
// pages/ArticlePage.jsx
import { useParams } from 'react-router-dom';
import { useArticleBySlug } from '../hooks/useArticleBySlug';

const MEDIA_URL = import.meta.env.VITE_MEDIA_URL;

export function ArticlePage({ collection = 'yaicos-articles' }) {
  const { slug } = useParams();
  const { article, loading, error } = useArticleBySlug(collection, slug);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;
  if (!article) return <div>Article not found</div>;

  const {
    title,
    content,
    featured_image,
    author,
    category,
    publishedAt,
    meta_title,
    meta_description
  } = article.attributes;

  const imageUrl = featured_image?.data?.attributes?.url
    ? `${MEDIA_URL}${featured_image.data.attributes.url}`
    : null;

  return (
    <article className="article-page">
      {/* SEO Meta Tags */}
      <head>
        <title>{meta_title || title}</title>
        <meta name="description" content={meta_description} />
      </head>

      <header>
        {imageUrl && (
          <img
            src={imageUrl}
            alt={featured_image.data.attributes.alternativeText || title}
            className="featured-image"
          />
        )}
        <span className="category">{category}</span>
        <h1>{title}</h1>
        <div className="meta">
          {author?.data && <span>By {author.data.attributes.name}</span>}
          <time>{new Date(publishedAt).toLocaleDateString()}</time>
        </div>
      </header>

      {/* Content is HTML from Strapi */}
      <div
        className="article-content"
        dangerouslySetInnerHTML={{ __html: content }}
      />
    </article>
  );
}
```

---

## 6. Important Notes

### CORS Configuration
The API is already configured to allow cross-origin requests from your frontend. No additional setup needed.

### Authentication
Currently, all blog endpoints are **public** (no authentication required). If this changes in the future, you'll need to add a Bearer token to requests:

```javascript
const response = await fetch(url, {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

### Media URLs
- Featured images are stored in `/uploads/` directory
- Full URL format: `https://cms.yaicos.com${imageUrl}`
- Images are optimized at 1792x1024 (16:9 landscape format)

### HTML Content Safety
The `content` field contains HTML generated by AI. It's sanitized server-side, but you should still use `dangerouslySetInnerHTML` carefully. Consider using a library like `DOMPurify` for extra safety:

```javascript
import DOMPurify from 'dompurify';

<div dangerouslySetInnerHTML={{
  __html: DOMPurify.sanitize(content)
}} />
```

### SEO Optimization
Each article includes:
- `meta_title` - Optimized page title
- `meta_description` - Optimized meta description
- `slug` - SEO-friendly URL

Use these in your meta tags for better SEO.

---

## 7. Quick Start Checklist

For the developer:

- [ ] Create `.env` file with `VITE_API_URL` and `VITE_MEDIA_URL`
- [ ] Install React Router (if using slug-based URLs): `npm install react-router-dom`
- [ ] Optional: Install DOMPurify for HTML sanitization: `npm install dompurify`
- [ ] Copy the `useArticles` and `useArticleBySlug` hooks
- [ ] Test fetching articles with: `GET https://cms.yaicos.com/api/yaicos-articles?populate=*&pagination[pageSize]=5`
- [ ] Build article list and single article pages using the examples above
- [ ] Implement pagination if needed
- [ ] Add category filtering if needed

---

## 8. Testing the API

### Quick Test (Browser or Postman)

**Fetch 3 latest Yaicos articles:**
```
https://cms.yaicos.com/api/yaicos-articles?populate=*&pagination[pageSize]=3&sort=publishedAt:desc
```

**Fetch articles in "technology" category:**
```
https://cms.yaicos.com/api/yaicos-articles?populate=*&filters[category][$eq]=technology
```

**Fetch specific article by slug:**
```
https://cms.yaicos.com/api/yaicos-articles?populate=*&filters[slug][$eq]=your-article-slug
```

---

## 9. Contact for Issues

If you encounter any issues:
1. Check the API is accessible: `https://cms.yaicos.com/api/yaicos-articles`
2. Verify the collection name matches exactly (yaicos-articles, guardscan-articles, or amabex-articles)
3. Ensure `populate=*` is included to get images and author data
4. Check browser console for CORS or network errors

---

**That's it!** The API is ready to use. Start with the simple examples above and expand as needed.
