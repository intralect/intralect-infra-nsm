# SEO-Optimized Blog Implementation Guide
## React + Vite + Tailwind CSS + Strapi CMS

> **For Claude Code**: Follow this guide exactly to implement a fully SEO-optimized blog system.

---

## 📋 Overview

This guide implements a blog system for three websites pulling content from a single Strapi CMS:

| Site | Strapi Collection | API Endpoint |
|------|-------------------|--------------|
| guardscan.io | `guardscan-articles` | `https://cms.yaicos.com/api/guardscan-articles` |
| yaicos.com | `yaicos-articles` | `https://cms.yaicos.com/api/yaicos-articles` |
| amabex.com | `amabex-articles` | `https://cms.yaicos.com/api/amabex-articles` |

---

## 🛠️ Prerequisites

Each React site needs these dependencies:

```bash
npm install react-helmet-async react-router-dom axios
```

---

## 📁 File Structure

Create this structure in each React project:

```
src/
├── components/
│   └── blog/
│       ├── BlogList.jsx          # Blog listing page
│       ├── BlogPost.jsx          # Single article page
│       ├── BlogCard.jsx          # Article preview card
│       ├── CategoryPage.jsx      # Category filter page
│       ├── AuthorBio.jsx         # Author information box
│       ├── Breadcrumbs.jsx       # Navigation breadcrumbs
│       ├── RelatedPosts.jsx      # Related articles section
│       ├── ShareButtons.jsx      # Social sharing buttons
│       └── SEO/
│           ├── SEOHead.jsx       # Meta tags component
│           └── JsonLd.jsx        # Structured data component
├── hooks/
│   ├── useStrapi.js              # Strapi API hook
│   └── useSEO.js                 # SEO utilities hook
├── utils/
│   ├── strapiClient.js           # Axios instance for Strapi
│   ├── formatDate.js             # Date formatting utility
│   └── calculateReadTime.js      # Reading time calculator
├── config/
│   └── site.js                   # Site-specific configuration
└── pages/
    ├── Blog.jsx                  # /blog route
    ├── BlogPostPage.jsx          # /blog/:slug route
    └── CategoryPage.jsx          # /blog/category/:category route
```

---

## ⚙️ Configuration Files

### `src/config/site.js`

**IMPORTANT**: Each site has its own config. Change values per site.

```javascript
// FOR GUARDSCAN.IO
const siteConfig = {
  name: "GuardScan",
  url: "https://guardscan.io",
  
  // Strapi Configuration
  strapi: {
    baseUrl: "https://cms.yaicos.com",
    collection: "guardscan-articles", // Change per site
  },
  
  // SEO Defaults
  seo: {
    titleTemplate: "%s | GuardScan Blog",
    defaultTitle: "GuardScan Blog - Security Insights & News",
    defaultDescription: "Expert security insights, guides, and news from GuardScan.",
    defaultImage: "/og-image.jpg",
    twitterHandle: "@guardscan",
  },
  
  // Blog Settings
  blog: {
    postsPerPage: 12,
    categories: ["security", "news", "guides", "tutorials"],
  },
};

export default siteConfig;
```

**For yaicos.com:**
```javascript
const siteConfig = {
  name: "Yaicos",
  url: "https://yaicos.com",
  strapi: {
    baseUrl: "https://cms.yaicos.com",
    collection: "yaicos-articles",
  },
  seo: {
    titleTemplate: "%s | Yaicos Blog",
    defaultTitle: "Yaicos Blog",
    defaultDescription: "Technology, business, and lifestyle insights.",
    defaultImage: "/og-image.jpg",
    twitterHandle: "@yaicos",
  },
  blog: {
    postsPerPage: 12,
    categories: ["technology", "business", "lifestyle", "news"],
  },
};
export default siteConfig;
```

**For amabex.com:**
```javascript
const siteConfig = {
  name: "Amabex",
  url: "https://amabex.com",
  strapi: {
    baseUrl: "https://cms.yaicos.com",
    collection: "amabex-articles",
  },
  seo: {
    titleTemplate: "%s | Amabex Blog",
    defaultTitle: "Amabex Blog",
    defaultDescription: "Products, services, and company updates.",
    defaultImage: "/og-image.jpg",
    twitterHandle: "@amabex",
  },
  blog: {
    postsPerPage: 12,
    categories: ["products", "services", "news", "updates"],
  },
};
export default siteConfig;
```

---

## 🔌 API Utilities

### `src/utils/strapiClient.js`

```javascript
import axios from 'axios';
import siteConfig from '../config/site';

const strapiClient = axios.create({
  baseURL: `${siteConfig.strapi.baseUrl}/api`,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Strapi returns data in { data: { attributes: {} } } format
// This helper extracts and flattens the response
export const flattenStrapiResponse = (response) => {
  const { data } = response;
  
  if (Array.isArray(data)) {
    return data.map((item) => ({
      id: item.id,
      ...item.attributes,
      // Handle nested media
      featured_image: item.attributes.featured_image?.data?.attributes || null,
      author: item.attributes.author?.data?.attributes || null,
    }));
  }
  
  return {
    id: data.id,
    ...data.attributes,
    featured_image: data.attributes.featured_image?.data?.attributes || null,
    author: data.attributes.author?.data?.attributes || null,
  };
};

export default strapiClient;
```

### `src/utils/formatDate.js`

```javascript
export const formatDate = (dateString, options = {}) => {
  const defaultOptions = {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    ...options,
  };
  
  return new Date(dateString).toLocaleDateString('en-US', defaultOptions);
};

export const formatDateISO = (dateString) => {
  return new Date(dateString).toISOString();
};
```

### `src/utils/calculateReadTime.js`

```javascript
export const calculateReadTime = (content) => {
  if (!content) return 1;
  
  // Strip HTML tags if present
  const text = content.replace(/<[^>]*>/g, '');
  
  // Average reading speed: 200 words per minute
  const wordsPerMinute = 200;
  const wordCount = text.trim().split(/\s+/).length;
  const readTime = Math.ceil(wordCount / wordsPerMinute);
  
  return readTime < 1 ? 1 : readTime;
};
```

---

## 🪝 Custom Hooks

### `src/hooks/useStrapi.js`

```javascript
import { useState, useEffect } from 'react';
import strapiClient, { flattenStrapiResponse } from '../utils/strapiClient';
import siteConfig from '../config/site';

const collection = siteConfig.strapi.collection;

// Fetch all articles with pagination
export const useArticles = (page = 1, pageSize = 12, category = null) => {
  const [articles, setArticles] = useState([]);
  const [pagination, setPagination] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchArticles = async () => {
      setLoading(true);
      try {
        const params = {
          populate: ['featured_image', 'author'],
          sort: 'publishedAt:desc',
          'pagination[page]': page,
          'pagination[pageSize]': pageSize,
        };
        
        if (category) {
          params['filters[category][$eq]'] = category;
        }
        
        // Only published articles
        params['filters[publishedAt][$notNull]'] = true;

        const response = await strapiClient.get(`/${collection}`, { params });
        
        setArticles(flattenStrapiResponse(response.data));
        setPagination(response.data.meta.pagination);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchArticles();
  }, [page, pageSize, category]);

  return { articles, pagination, loading, error };
};

// Fetch single article by slug
export const useArticle = (slug) => {
  const [article, setArticle] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchArticle = async () => {
      if (!slug) return;
      
      setLoading(true);
      try {
        const response = await strapiClient.get(`/${collection}`, {
          params: {
            'filters[slug][$eq]': slug,
            populate: ['featured_image', 'author', 'author.avatar'],
          },
        });

        const articles = flattenStrapiResponse(response.data);
        setArticle(articles[0] || null);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchArticle();
  }, [slug]);

  return { article, loading, error };
};

// Fetch related articles (same category, exclude current)
export const useRelatedArticles = (category, currentSlug, limit = 3) => {
  const [articles, setArticles] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchRelated = async () => {
      if (!category) return;
      
      try {
        const response = await strapiClient.get(`/${collection}`, {
          params: {
            'filters[category][$eq]': category,
            'filters[slug][$ne]': currentSlug,
            'filters[publishedAt][$notNull]': true,
            populate: ['featured_image'],
            sort: 'publishedAt:desc',
            'pagination[limit]': limit,
          },
        });

        setArticles(flattenStrapiResponse(response.data));
      } catch (err) {
        console.error('Error fetching related articles:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchRelated();
  }, [category, currentSlug, limit]);

  return { articles, loading };
};

// Fetch all categories with article counts
export const useCategories = () => {
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        // Fetch all articles to count categories
        const response = await strapiClient.get(`/${collection}`, {
          params: {
            'filters[publishedAt][$notNull]': true,
            'pagination[limit]': 1000,
            fields: ['category'],
          },
        });

        const articles = flattenStrapiResponse(response.data);
        const categoryCounts = articles.reduce((acc, article) => {
          const cat = article.category;
          if (cat) {
            acc[cat] = (acc[cat] || 0) + 1;
          }
          return acc;
        }, {});

        setCategories(
          Object.entries(categoryCounts).map(([name, count]) => ({
            name,
            count,
            slug: name.toLowerCase(),
          }))
        );
      } catch (err) {
        console.error('Error fetching categories:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchCategories();
  }, []);

  return { categories, loading };
};
```

---

## 🔍 SEO Components

### `src/components/blog/SEO/SEOHead.jsx`

```javascript
import { Helmet } from 'react-helmet-async';
import siteConfig from '../../../config/site';

const SEOHead = ({
  title,
  description,
  image,
  url,
  type = 'article',
  publishedTime,
  modifiedTime,
  author,
  noindex = false,
}) => {
  const seo = {
    title: title 
      ? siteConfig.seo.titleTemplate.replace('%s', title)
      : siteConfig.seo.defaultTitle,
    description: description || siteConfig.seo.defaultDescription,
    image: image || `${siteConfig.url}${siteConfig.seo.defaultImage}`,
    url: url || siteConfig.url,
  };

  return (
    <Helmet>
      {/* Basic Meta Tags */}
      <title>{seo.title}</title>
      <meta name="description" content={seo.description} />
      <link rel="canonical" href={seo.url} />
      
      {noindex && <meta name="robots" content="noindex,nofollow" />}

      {/* Open Graph */}
      <meta property="og:type" content={type} />
      <meta property="og:title" content={seo.title} />
      <meta property="og:description" content={seo.description} />
      <meta property="og:image" content={seo.image} />
      <meta property="og:url" content={seo.url} />
      <meta property="og:site_name" content={siteConfig.name} />
      
      {publishedTime && (
        <meta property="article:published_time" content={publishedTime} />
      )}
      {modifiedTime && (
        <meta property="article:modified_time" content={modifiedTime} />
      )}
      {author && <meta property="article:author" content={author} />}

      {/* Twitter Card */}
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:site" content={siteConfig.seo.twitterHandle} />
      <meta name="twitter:title" content={seo.title} />
      <meta name="twitter:description" content={seo.description} />
      <meta name="twitter:image" content={seo.image} />
    </Helmet>
  );
};

export default SEOHead;
```

### `src/components/blog/SEO/JsonLd.jsx`

```javascript
import { Helmet } from 'react-helmet-async';
import siteConfig from '../../../config/site';

// Article Schema
export const ArticleJsonLd = ({ article }) => {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: article.title,
    description: article.excerpt || article.seo_description,
    image: article.featured_image?.url,
    datePublished: article.publishedAt,
    dateModified: article.updatedAt || article.publishedAt,
    author: {
      '@type': 'Person',
      name: article.author?.name || siteConfig.name,
    },
    publisher: {
      '@type': 'Organization',
      name: siteConfig.name,
      logo: {
        '@type': 'ImageObject',
        url: `${siteConfig.url}/logo.png`,
      },
    },
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': `${siteConfig.url}/blog/${article.slug}`,
    },
  };

  return (
    <Helmet>
      <script type="application/ld+json">{JSON.stringify(schema)}</script>
    </Helmet>
  );
};

// Breadcrumb Schema
export const BreadcrumbJsonLd = ({ items }) => {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: item.url,
    })),
  };

  return (
    <Helmet>
      <script type="application/ld+json">{JSON.stringify(schema)}</script>
    </Helmet>
  );
};

// Blog Listing Schema
export const BlogListJsonLd = ({ articles }) => {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Blog',
    name: `${siteConfig.name} Blog`,
    description: siteConfig.seo.defaultDescription,
    url: `${siteConfig.url}/blog`,
    blogPost: articles.slice(0, 10).map((article) => ({
      '@type': 'BlogPosting',
      headline: article.title,
      url: `${siteConfig.url}/blog/${article.slug}`,
      datePublished: article.publishedAt,
      image: article.featured_image?.url,
    })),
  };

  return (
    <Helmet>
      <script type="application/ld+json">{JSON.stringify(schema)}</script>
    </Helmet>
  );
};

// Organization Schema (put in layout/root)
export const OrganizationJsonLd = () => {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: siteConfig.name,
    url: siteConfig.url,
    logo: `${siteConfig.url}/logo.png`,
    sameAs: [
      `https://twitter.com/${siteConfig.seo.twitterHandle.replace('@', '')}`,
      // Add other social links
    ],
  };

  return (
    <Helmet>
      <script type="application/ld+json">{JSON.stringify(schema)}</script>
    </Helmet>
  );
};
```

---

## 📄 Blog Components

### `src/components/blog/BlogCard.jsx`

```javascript
import { Link } from 'react-router-dom';
import { formatDate } from '../../utils/formatDate';
import { calculateReadTime } from '../../utils/calculateReadTime';
import siteConfig from '../../config/site';

const BlogCard = ({ article }) => {
  const imageUrl = article.featured_image?.url
    ? `${siteConfig.strapi.baseUrl}${article.featured_image.url}`
    : '/placeholder-blog.jpg';

  return (
    <article className="group bg-white rounded-xl shadow-sm hover:shadow-lg transition-all duration-300 overflow-hidden">
      {/* Image */}
      <Link to={`/blog/${article.slug}`} className="block aspect-video overflow-hidden">
        <img
          src={imageUrl}
          alt={article.title}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
          loading="lazy"
        />
      </Link>

      {/* Content */}
      <div className="p-6">
        {/* Category Badge */}
        {article.category && (
          <Link
            to={`/blog/category/${article.category}`}
            className="inline-block px-3 py-1 text-xs font-medium text-primary-600 bg-primary-50 rounded-full hover:bg-primary-100 transition-colors"
          >
            {article.category}
          </Link>
        )}

        {/* Title */}
        <h2 className="mt-3 text-xl font-bold text-gray-900 group-hover:text-primary-600 transition-colors">
          <Link to={`/blog/${article.slug}`}>{article.title}</Link>
        </h2>

        {/* Excerpt */}
        {article.excerpt && (
          <p className="mt-2 text-gray-600 line-clamp-2">{article.excerpt}</p>
        )}

        {/* Meta */}
        <div className="mt-4 flex items-center justify-between text-sm text-gray-500">
          <time dateTime={article.publishedAt}>
            {formatDate(article.publishedAt)}
          </time>
          <span>{calculateReadTime(article.content)} min read</span>
        </div>
      </div>
    </article>
  );
};

export default BlogCard;
```

### `src/components/blog/Breadcrumbs.jsx`

```javascript
import { Link } from 'react-router-dom';
import { BreadcrumbJsonLd } from './SEO/JsonLd';
import siteConfig from '../../config/site';

const Breadcrumbs = ({ items }) => {
  // Add home as first item
  const breadcrumbItems = [
    { name: 'Home', url: siteConfig.url, path: '/' },
    ...items,
  ];

  return (
    <>
      <BreadcrumbJsonLd items={breadcrumbItems} />
      
      <nav aria-label="Breadcrumb" className="mb-6">
        <ol className="flex items-center space-x-2 text-sm text-gray-500">
          {breadcrumbItems.map((item, index) => (
            <li key={item.path} className="flex items-center">
              {index > 0 && (
                <svg
                  className="w-4 h-4 mx-2 text-gray-400"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path
                    fillRule="evenodd"
                    d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                    clipRule="evenodd"
                  />
                </svg>
              )}
              {index === breadcrumbItems.length - 1 ? (
                <span className="text-gray-900 font-medium">{item.name}</span>
              ) : (
                <Link
                  to={item.path}
                  className="hover:text-primary-600 transition-colors"
                >
                  {item.name}
                </Link>
              )}
            </li>
          ))}
        </ol>
      </nav>
    </>
  );
};

export default Breadcrumbs;
```

### `src/components/blog/AuthorBio.jsx`

```javascript
import siteConfig from '../../config/site';

const AuthorBio = ({ author }) => {
  if (!author) return null;

  const avatarUrl = author.avatar?.url
    ? `${siteConfig.strapi.baseUrl}${author.avatar.url}`
    : '/default-avatar.jpg';

  return (
    <div className="flex items-start gap-4 p-6 bg-gray-50 rounded-xl">
      <img
        src={avatarUrl}
        alt={author.name}
        className="w-16 h-16 rounded-full object-cover"
      />
      <div>
        <p className="text-sm text-gray-500 uppercase tracking-wide">Written by</p>
        <h3 className="text-lg font-bold text-gray-900">{author.name}</h3>
        {author.bio && <p className="mt-1 text-gray-600">{author.bio}</p>}
      </div>
    </div>
  );
};

export default AuthorBio;
```

### `src/components/blog/RelatedPosts.jsx`

```javascript
import { Link } from 'react-router-dom';
import { useRelatedArticles } from '../../hooks/useStrapi';
import siteConfig from '../../config/site';

const RelatedPosts = ({ category, currentSlug }) => {
  const { articles, loading } = useRelatedArticles(category, currentSlug, 3);

  if (loading || articles.length === 0) return null;

  return (
    <section className="mt-12 pt-12 border-t">
      <h2 className="text-2xl font-bold text-gray-900 mb-6">Related Articles</h2>
      
      <div className="grid md:grid-cols-3 gap-6">
        {articles.map((article) => {
          const imageUrl = article.featured_image?.url
            ? `${siteConfig.strapi.baseUrl}${article.featured_image.url}`
            : '/placeholder-blog.jpg';

          return (
            <Link
              key={article.id}
              to={`/blog/${article.slug}`}
              className="group block"
            >
              <div className="aspect-video rounded-lg overflow-hidden mb-3">
                <img
                  src={imageUrl}
                  alt={article.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  loading="lazy"
                />
              </div>
              <h3 className="font-semibold text-gray-900 group-hover:text-primary-600 transition-colors line-clamp-2">
                {article.title}
              </h3>
            </Link>
          );
        })}
      </div>
    </section>
  );
};

export default RelatedPosts;
```

### `src/components/blog/ShareButtons.jsx`

```javascript
import siteConfig from '../../config/site';

const ShareButtons = ({ title, slug }) => {
  const url = `${siteConfig.url}/blog/${slug}`;
  const encodedUrl = encodeURIComponent(url);
  const encodedTitle = encodeURIComponent(title);

  const shareLinks = [
    {
      name: 'Twitter',
      url: `https://twitter.com/intent/tweet?text=${encodedTitle}&url=${encodedUrl}`,
      icon: (
        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
        </svg>
      ),
    },
    {
      name: 'LinkedIn',
      url: `https://www.linkedin.com/sharing/share-offsite/?url=${encodedUrl}`,
      icon: (
        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
        </svg>
      ),
    },
    {
      name: 'Facebook',
      url: `https://www.facebook.com/sharer/sharer.php?u=${encodedUrl}`,
      icon: (
        <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
        </svg>
      ),
    },
  ];

  return (
    <div className="flex items-center gap-3">
      <span className="text-sm text-gray-500">Share:</span>
      {shareLinks.map((link) => (
        <a
          key={link.name}
          href={link.url}
          target="_blank"
          rel="noopener noreferrer"
          className="p-2 text-gray-500 hover:text-primary-600 hover:bg-gray-100 rounded-full transition-colors"
          aria-label={`Share on ${link.name}`}
        >
          {link.icon}
        </a>
      ))}
    </div>
  );
};

export default ShareButtons;
```

---

## 📃 Page Components

### `src/components/blog/BlogList.jsx`

```javascript
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useArticles, useCategories } from '../../hooks/useStrapi';
import BlogCard from './BlogCard';
import SEOHead from './SEO/SEOHead';
import { BlogListJsonLd } from './SEO/JsonLd';
import Breadcrumbs from './Breadcrumbs';
import siteConfig from '../../config/site';

const BlogList = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parseInt(searchParams.get('page')) || 1;
  
  const { articles, pagination, loading, error } = useArticles(
    page,
    siteConfig.blog.postsPerPage
  );
  const { categories } = useCategories();

  const handlePageChange = (newPage) => {
    setSearchParams({ page: newPage.toString() });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  if (error) {
    return <div className="text-center py-12 text-red-600">Error: {error}</div>;
  }

  return (
    <>
      <SEOHead
        title="Blog"
        description={`Latest articles and insights from ${siteConfig.name}`}
        url={`${siteConfig.url}/blog`}
        type="website"
      />
      <BlogListJsonLd articles={articles} />

      <div className="max-w-7xl mx-auto px-4 py-12">
        <Breadcrumbs
          items={[
            { name: 'Blog', url: `${siteConfig.url}/blog`, path: '/blog' },
          ]}
        />

        {/* Header */}
        <header className="text-center mb-12">
          <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-4">
            {siteConfig.name} Blog
          </h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            {siteConfig.seo.defaultDescription}
          </p>
        </header>

        {/* Categories */}
        {categories.length > 0 && (
          <nav className="flex flex-wrap justify-center gap-2 mb-10">
            <Link
              to="/blog"
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-full hover:bg-gray-200 transition-colors"
            >
              All
            </Link>
            {categories.map((category) => (
              <Link
                key={category.slug}
                to={`/blog/category/${category.slug}`}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-full hover:bg-gray-200 transition-colors"
              >
                {category.name} ({category.count})
              </Link>
            ))}
          </nav>
        )}

        {/* Articles Grid */}
        {loading ? (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="animate-pulse">
                <div className="aspect-video bg-gray-200 rounded-xl mb-4" />
                <div className="h-4 bg-gray-200 rounded w-1/4 mb-3" />
                <div className="h-6 bg-gray-200 rounded w-3/4 mb-2" />
                <div className="h-4 bg-gray-200 rounded w-full" />
              </div>
            ))}
          </div>
        ) : (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {articles.map((article) => (
              <BlogCard key={article.id} article={article} />
            ))}
          </div>
        )}

        {/* Empty State */}
        {!loading && articles.length === 0 && (
          <div className="text-center py-12">
            <p className="text-gray-500">No articles found.</p>
          </div>
        )}

        {/* Pagination */}
        {pagination && pagination.pageCount > 1 && (
          <nav className="flex justify-center items-center gap-2 mt-12">
            <button
              onClick={() => handlePageChange(page - 1)}
              disabled={page === 1}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>
            
            <span className="px-4 py-2 text-sm text-gray-600">
              Page {page} of {pagination.pageCount}
            </span>
            
            <button
              onClick={() => handlePageChange(page + 1)}
              disabled={page === pagination.pageCount}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>
          </nav>
        )}
      </div>
    </>
  );
};

export default BlogList;
```

### `src/components/blog/BlogPost.jsx`

```javascript
import { useParams } from 'react-router-dom';
import { useArticle } from '../../hooks/useStrapi';
import SEOHead from './SEO/SEOHead';
import { ArticleJsonLd } from './SEO/JsonLd';
import Breadcrumbs from './Breadcrumbs';
import AuthorBio from './AuthorBio';
import RelatedPosts from './RelatedPosts';
import ShareButtons from './ShareButtons';
import { formatDate, formatDateISO } from '../../utils/formatDate';
import { calculateReadTime } from '../../utils/calculateReadTime';
import siteConfig from '../../config/site';

const BlogPost = () => {
  const { slug } = useParams();
  const { article, loading, error } = useArticle(slug);

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-3/4 mb-4" />
          <div className="h-4 bg-gray-200 rounded w-1/4 mb-8" />
          <div className="aspect-video bg-gray-200 rounded-xl mb-8" />
          <div className="space-y-4">
            {[...Array(8)].map((_, i) => (
              <div key={i} className="h-4 bg-gray-200 rounded" />
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (error || !article) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 text-center">
        <h1 className="text-2xl font-bold text-gray-900 mb-4">Article Not Found</h1>
        <p className="text-gray-600">The article you're looking for doesn't exist.</p>
      </div>
    );
  }

  const imageUrl = article.featured_image?.url
    ? `${siteConfig.strapi.baseUrl}${article.featured_image.url}`
    : null;

  const readTime = calculateReadTime(article.content);

  return (
    <>
      <SEOHead
        title={article.seo_title || article.title}
        description={article.seo_description || article.excerpt}
        image={imageUrl}
        url={`${siteConfig.url}/blog/${article.slug}`}
        type="article"
        publishedTime={formatDateISO(article.publishedAt)}
        modifiedTime={formatDateISO(article.updatedAt)}
        author={article.author?.name}
      />
      <ArticleJsonLd article={article} />

      <article className="max-w-4xl mx-auto px-4 py-12">
        <Breadcrumbs
          items={[
            { name: 'Blog', url: `${siteConfig.url}/blog`, path: '/blog' },
            {
              name: article.title,
              url: `${siteConfig.url}/blog/${article.slug}`,
              path: `/blog/${article.slug}`,
            },
          ]}
        />

        {/* Article Header */}
        <header className="mb-8">
          {article.category && (
            <a
              href={`/blog/category/${article.category}`}
              className="inline-block px-3 py-1 text-sm font-medium text-primary-600 bg-primary-50 rounded-full mb-4"
            >
              {article.category}
            </a>
          )}
          
          <h1 className="text-3xl md:text-4xl lg:text-5xl font-bold text-gray-900 mb-4">
            {article.title}
          </h1>

          <div className="flex flex-wrap items-center gap-4 text-gray-500">
            {article.author && (
              <span className="flex items-center gap-2">
                {article.author.avatar && (
                  <img
                    src={`${siteConfig.strapi.baseUrl}${article.author.avatar.url}`}
                    alt={article.author.name}
                    className="w-8 h-8 rounded-full"
                  />
                )}
                <span>{article.author.name}</span>
              </span>
            )}
            <time dateTime={article.publishedAt}>
              {formatDate(article.publishedAt)}
            </time>
            <span>{readTime} min read</span>
          </div>
        </header>

        {/* Featured Image */}
        {imageUrl && (
          <figure className="mb-8">
            <img
              src={imageUrl}
              alt={article.title}
              className="w-full rounded-xl"
            />
          </figure>
        )}

        {/* Article Content */}
        <div
          className="prose prose-lg max-w-none mb-8
            prose-headings:font-bold prose-headings:text-gray-900
            prose-p:text-gray-700 prose-p:leading-relaxed
            prose-a:text-primary-600 prose-a:no-underline hover:prose-a:underline
            prose-img:rounded-xl
            prose-blockquote:border-l-primary-500 prose-blockquote:bg-gray-50 prose-blockquote:py-1 prose-blockquote:px-4 prose-blockquote:rounded-r-lg"
          dangerouslySetInnerHTML={{ __html: article.content }}
        />

        {/* Share Buttons */}
        <div className="border-t border-b py-6 my-8">
          <ShareButtons title={article.title} slug={article.slug} />
        </div>

        {/* Author Bio */}
        <AuthorBio author={article.author} />

        {/* Related Posts */}
        <RelatedPosts category={article.category} currentSlug={article.slug} />
      </article>
    </>
  );
};

export default BlogPost;
```

### `src/components/blog/CategoryPage.jsx`

```javascript
import { useParams, Link, useSearchParams } from 'react-router-dom';
import { useArticles } from '../../hooks/useStrapi';
import BlogCard from './BlogCard';
import SEOHead from './SEO/SEOHead';
import Breadcrumbs from './Breadcrumbs';
import siteConfig from '../../config/site';

const CategoryPage = () => {
  const { category } = useParams();
  const [searchParams, setSearchParams] = useSearchParams();
  const page = parseInt(searchParams.get('page')) || 1;

  const { articles, pagination, loading, error } = useArticles(
    page,
    siteConfig.blog.postsPerPage,
    category
  );

  const handlePageChange = (newPage) => {
    setSearchParams({ page: newPage.toString() });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  // Capitalize category name for display
  const categoryName = category.charAt(0).toUpperCase() + category.slice(1);

  return (
    <>
      <SEOHead
        title={`${categoryName} Articles`}
        description={`Browse all ${categoryName.toLowerCase()} articles on ${siteConfig.name}`}
        url={`${siteConfig.url}/blog/category/${category}`}
        type="website"
      />

      <div className="max-w-7xl mx-auto px-4 py-12">
        <Breadcrumbs
          items={[
            { name: 'Blog', url: `${siteConfig.url}/blog`, path: '/blog' },
            {
              name: categoryName,
              url: `${siteConfig.url}/blog/category/${category}`,
              path: `/blog/category/${category}`,
            },
          ]}
        />

        {/* Header */}
        <header className="text-center mb-12">
          <span className="inline-block px-4 py-1 text-sm font-medium text-primary-600 bg-primary-50 rounded-full mb-4">
            Category
          </span>
          <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-4">
            {categoryName}
          </h1>
          <p className="text-xl text-gray-600">
            {pagination?.total || 0} articles in this category
          </p>
        </header>

        {/* Back Link */}
        <div className="mb-8">
          <Link
            to="/blog"
            className="inline-flex items-center text-primary-600 hover:text-primary-700"
          >
            <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
            Back to all articles
          </Link>
        </div>

        {/* Error State */}
        {error && (
          <div className="text-center py-12 text-red-600">Error: {error}</div>
        )}

        {/* Loading State */}
        {loading && (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="animate-pulse">
                <div className="aspect-video bg-gray-200 rounded-xl mb-4" />
                <div className="h-4 bg-gray-200 rounded w-1/4 mb-3" />
                <div className="h-6 bg-gray-200 rounded w-3/4 mb-2" />
                <div className="h-4 bg-gray-200 rounded w-full" />
              </div>
            ))}
          </div>
        )}

        {/* Articles Grid */}
        {!loading && articles.length > 0 && (
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {articles.map((article) => (
              <BlogCard key={article.id} article={article} />
            ))}
          </div>
        )}

        {/* Empty State */}
        {!loading && articles.length === 0 && (
          <div className="text-center py-12">
            <p className="text-gray-500 mb-4">No articles in this category yet.</p>
            <Link to="/blog" className="text-primary-600 hover:text-primary-700">
              Browse all articles
            </Link>
          </div>
        )}

        {/* Pagination */}
        {pagination && pagination.pageCount > 1 && (
          <nav className="flex justify-center items-center gap-2 mt-12">
            <button
              onClick={() => handlePageChange(page - 1)}
              disabled={page === 1}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>
            
            <span className="px-4 py-2 text-sm text-gray-600">
              Page {page} of {pagination.pageCount}
            </span>
            
            <button
              onClick={() => handlePageChange(page + 1)}
              disabled={page === pagination.pageCount}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>
          </nav>
        )}
      </div>
    </>
  );
};

export default CategoryPage;
```

---

## 🔧 Router Setup

### `src/App.jsx` (add blog routes)

```javascript
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { HelmetProvider } from 'react-helmet-async';

// Blog Components
import BlogList from './components/blog/BlogList';
import BlogPost from './components/blog/BlogPost';
import CategoryPage from './components/blog/CategoryPage';

// Your existing components
import Layout from './components/Layout';
import Home from './pages/Home';
// ... other imports

function App() {
  return (
    <HelmetProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Layout />}>
            <Route index element={<Home />} />
            
            {/* Blog Routes */}
            <Route path="blog" element={<BlogList />} />
            <Route path="blog/:slug" element={<BlogPost />} />
            <Route path="blog/category/:category" element={<CategoryPage />} />
            
            {/* ... other routes */}
          </Route>
        </Routes>
      </BrowserRouter>
    </HelmetProvider>
  );
}

export default App;
```

---

## 🌐 Strapi API Permissions

**IMPORTANT**: Enable public read access in Strapi:

1. Go to `https://cms.yaicos.com/admin`
2. Settings → Users & Permissions Plugin → Roles → Public
3. Under your collection (e.g., `guardscan-article`):
   - Enable: `find`, `findOne`
4. Under `Author`:
   - Enable: `find`, `findOne`
5. Under `Upload`:
   - Enable: `find`, `findOne`
6. **Save**

---

## 📋 SEO Checklist

### Per Article (in Strapi)
- [ ] `title` - Compelling, 50-60 characters
- [ ] `slug` - URL-friendly, includes keywords
- [ ] `excerpt` - 150-160 characters summary
- [ ] `seo_title` - If different from title
- [ ] `seo_description` - Unique, includes keywords
- [ ] `featured_image` - Optimized, with alt text
- [ ] `category` - Properly assigned

### Technical SEO (per site)
- [ ] `/robots.txt` - Allow crawling
- [ ] `/sitemap.xml` - Generate dynamically or at build
- [ ] Canonical URLs - Set on all pages
- [ ] Mobile responsive - Test all breakpoints
- [ ] Page speed - Lazy load images, optimize bundles

---

## 🎨 Styling Notes

The components use Tailwind CSS with these conventions:

- `primary-*` - Your brand color (configure in `tailwind.config.js`)
- `gray-*` - Neutral colors
- Responsive: `md:` for tablets, `lg:` for desktop

### Configure brand colors in `tailwind.config.js`:

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'), // For prose styles
  ],
};
```

Install typography plugin:
```bash
npm install @tailwindcss/typography
```

---

## 🚀 Deployment Checklist

1. [ ] Install dependencies: `npm install react-helmet-async react-router-dom axios @tailwindcss/typography`
2. [ ] Create all files from this guide
3. [ ] Update `src/config/site.js` for your specific site
4. [ ] Enable Strapi public permissions
5. [ ] Test all routes locally
6. [ ] Create test article in Strapi
7. [ ] Verify SEO meta tags (use browser dev tools)
8. [ ] Test Open Graph (use Facebook Sharing Debugger)
9. [ ] Verify JSON-LD (use Google Rich Results Test)
10. [ ] Deploy

---

## 📝 Summary

This implementation provides:

- ✅ Full SEO optimization (meta tags, Open Graph, Twitter Cards)
- ✅ Structured data (JSON-LD for Articles, Breadcrumbs, Organization)
- ✅ Blog listing with pagination
- ✅ Single article pages with rich formatting
- ✅ Category filtering
- ✅ Related posts
- ✅ Author bio section
- ✅ Social sharing buttons
- ✅ Breadcrumb navigation
- ✅ Reading time calculation
- ✅ Loading states and error handling
- ✅ Responsive design with Tailwind CSS
- ✅ Same components, different config per site
