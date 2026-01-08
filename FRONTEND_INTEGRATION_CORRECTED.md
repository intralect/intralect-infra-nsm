# Yaicos Blog Frontend Integration - CORRECTED GUIDE

**Date:** 2026-01-08
**For:** Yaicos.com Frontend Developer
**Strapi CMS:** https://cms.yaicos.com

---

## CRITICAL CORRECTIONS to Initial Plan

### 1. Content Type Name
❌ **WRONG:** `/api/articles`
✅ **CORRECT:** `/api/yaicos-articles`

Your Strapi uses **separate content types per brand**:
- `yaicos-articles` - Yaicos (study abroad)
- `guardscan-articles` - GuardScan (cybersecurity)
- `amabex-articles` - Amabex (business)

### 2. Categories are NOT a Separate Collection
❌ **WRONG:** Categories are a relation to `/api/categories`
✅ **CORRECT:** Categories are an **enumeration** (fixed list)

**Available Yaicos Categories:**
- `alojamiento` (Accommodation)
- `visa` (Visa)
- `trabajo` (Work)
- `costo de vida` (Cost of Living)
- `estilo de vida` (Lifestyle)
- `transporte` (Transportation)
- `turismo` (Tourism)
- `migracion` (Migration)

### 3. Field Names Use Underscores
❌ **WRONG:** `featuredImage`, `metaTitle`, `metaDescription`
✅ **CORRECT:** `featured_image`, `meta_title`, `meta_description`

---

## Actual Strapi Schema

### YaicosArticle Interface (TypeScript)

```typescript
interface YaicosArticle {
  id: number;
  attributes: {
    // Core Content
    title: string;
    slug: string;
    content: string; // Rich text HTML
    excerpt: string; // Max 300 chars

    // Media
    featured_image: {
      data: {
        id: number;
        attributes: {
          url: string;
          alternativeText: string;
          width: number;
          height: number;
          formats?: {
            thumbnail: { url: string };
            small: { url: string };
            medium: { url: string };
            large: { url: string };
          };
        };
      } | null;
    };

    // Category (Enum, not relation!)
    category:
      | "alojamiento"
      | "visa"
      | "trabajo"
      | "costo de vida"
      | "estilo de vida"
      | "transporte"
      | "turismo"
      | "migracion"
      | null;

    // SEO
    meta_title: string; // Max 60 chars
    meta_description: string; // Max 160 chars
    canonical_url: string | null;
    no_index: boolean;

    // Open Graph
    og_image: {
      data: {
        attributes: {
          url: string;
          alternativeText: string;
        };
      } | null;
    };
    og_image_alt: string | null;
    og_image_width: number; // Default: 1200
    og_image_height: number; // Default: 630

    // Author (Relation)
    author: {
      data: {
        id: number;
        attributes: {
          name: string;
          bio: string;
          email: string;
          avatar: {
            data: {
              attributes: {
                url: string;
              };
            } | null;
          };
        };
      } | null;
    };

    // Metadata
    publishedAt: string; // ISO date
    createdAt: string;
    updatedAt: string;

    // AI Features
    ai_generated: boolean;
    embedding: number[] | null; // Vector embedding for semantic search
  };
}
```

---

## Corrected API Client

**File: `src/lib/strapi.ts`**

```typescript
const STRAPI_URL = "https://cms.yaicos.com";
const STRAPI_API = `${STRAPI_URL}/api`;

export interface StrapiResponse<T> {
  data: T;
  meta?: {
    pagination?: {
      page: number;
      pageSize: number;
      pageCount: number;
      total: number;
    };
  };
}

// Fetch Yaicos articles with pagination and category filter
export async function fetchYaicosArticles(
  page = 1,
  pageSize = 9,
  category?: string
): Promise<StrapiResponse<YaicosArticle[]>> {
  let url = `${STRAPI_API}/yaicos-articles?populate[featured_image]=*&populate[author][populate][avatar]=*&pagination[page]=${page}&pagination[pageSize]=${pageSize}&sort[0]=publishedAt:desc`;

  // Filter by category (enum, not relation)
  if (category) {
    url += `&filters[category][$eq]=${category}`;
  }

  const response = await fetch(url);
  if (!response.ok) throw new Error("Failed to fetch Yaicos articles");
  return response.json();
}

// Fetch single Yaicos article by slug
export async function fetchYaicosArticleBySlug(
  slug: string
): Promise<StrapiResponse<YaicosArticle[]>> {
  const url = `${STRAPI_API}/yaicos-articles?filters[slug][$eq]=${slug}&populate[featured_image]=*&populate[author][populate][avatar]=*&populate[og_image]=*`;

  const response = await fetch(url);
  if (!response.ok) throw new Error("Failed to fetch Yaicos article");
  return response.json();
}

// Get all available categories (static list, not from API)
export function getYaicosCategories() {
  return [
    { slug: "alojamiento", name: "Alojamiento", icon: "🏠" },
    { slug: "visa", name: "Visa", icon: "📝" },
    { slug: "trabajo", name: "Trabajo", icon: "💼" },
    { slug: "costo-de-vida", name: "Costo de Vida", icon: "💰" },
    { slug: "estilo-de-vida", name: "Estilo de Vida", icon: "🌟" },
    { slug: "transporte", name: "Transporte", icon: "🚇" },
    { slug: "turismo", name: "Turismo", icon: "✈️" },
    { slug: "migracion", name: "Migración", icon: "🌍" },
  ];
}

// Search articles by keyword (semantic search if available)
export async function searchYaicosArticles(
  query: string
): Promise<StrapiResponse<YaicosArticle[]>> {
  const url = `${STRAPI_API}/yaicos-articles?filters[title][$containsi]=${query}&populate[featured_image]=*&populate[author][populate][avatar]=*`;

  const response = await fetch(url);
  if (!response.ok) throw new Error("Failed to search articles");
  return response.json();
}

// Helper to get full image URL
export function getStrapiMedia(url: string | undefined | null): string | null {
  if (!url) return null;
  if (url.startsWith("http")) return url;
  return `${STRAPI_URL}${url}`;
}

// Helper to format category display name
export function formatCategoryName(slug: string): string {
  const categories = getYaicosCategories();
  return categories.find((c) => c.slug === slug)?.name || slug;
}
```

---

## Corrected React Query Hooks

**File: `src/hooks/useBlog.ts`**

```typescript
import { useQuery } from "@tanstack/react-query";
import {
  fetchYaicosArticles,
  fetchYaicosArticleBySlug,
  searchYaicosArticles,
} from "@/lib/strapi";

export function useYaicosArticles(page = 1, category?: string) {
  return useQuery({
    queryKey: ["yaicos-articles", page, category],
    queryFn: () => fetchYaicosArticles(page, 9, category),
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

export function useYaicosArticle(slug: string) {
  return useQuery({
    queryKey: ["yaicos-article", slug],
    queryFn: () => fetchYaicosArticleBySlug(slug),
    enabled: !!slug,
  });
}

export function useYaicosSearch(query: string) {
  return useQuery({
    queryKey: ["yaicos-search", query],
    queryFn: () => searchYaicosArticles(query),
    enabled: query.length > 2, // Only search if 3+ characters
    staleTime: 2 * 60 * 1000, // 2 minutes
  });
}
```

---

## Example API Responses

### List Articles Response

```json
{
  "data": [
    {
      "id": 1,
      "attributes": {
        "title": "Guía Completa: Cómo Conseguir Alojamiento en Alemania",
        "slug": "como-conseguir-alojamiento-alemania",
        "excerpt": "Descubre los mejores consejos para encontrar alojamiento estudiantil en Alemania...",
        "content": "<h2>Introducción</h2><p>Encontrar alojamiento en Alemania...</p>",
        "category": "alojamiento",
        "meta_title": "Alojamiento en Alemania: Guía Completa 2026",
        "meta_description": "Todo lo que necesitas saber para encontrar alojamiento estudiantil en Alemania. WG, Wohnheim, y más opciones.",
        "featured_image": {
          "data": {
            "id": 5,
            "attributes": {
              "url": "/uploads/alojamiento_alemania_123abc.png",
              "alternativeText": "Estudiante buscando alojamiento en Alemania",
              "width": 1792,
              "height": 1024,
              "formats": {
                "large": { "url": "/uploads/large_alojamiento_123.png" },
                "medium": { "url": "/uploads/medium_alojamiento_123.png" },
                "small": { "url": "/uploads/small_alojamiento_123.png" },
                "thumbnail": { "url": "/uploads/thumb_alojamiento_123.png" }
              }
            }
          }
        },
        "author": {
          "data": {
            "id": 1,
            "attributes": {
              "name": "Ana García",
              "bio": "Consultora educativa con 5 años de experiencia ayudando a estudiantes latinoamericanos.",
              "email": "ana@yaicos.com",
              "avatar": {
                "data": {
                  "attributes": {
                    "url": "/uploads/avatar_ana.jpg"
                  }
                }
              }
            }
          }
        },
        "og_image": {
          "data": {
            "attributes": {
              "url": "/uploads/og_alojamiento_123.png",
              "alternativeText": "Alojamiento en Alemania"
            }
          }
        },
        "og_image_alt": "Guía de alojamiento para estudiantes en Alemania",
        "og_image_width": 1200,
        "og_image_height": 630,
        "canonical_url": null,
        "no_index": false,
        "ai_generated": true,
        "embedding": null,
        "publishedAt": "2026-01-05T10:30:00.000Z",
        "createdAt": "2026-01-05T10:00:00.000Z",
        "updatedAt": "2026-01-05T10:30:00.000Z"
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "pageSize": 9,
      "pageCount": 3,
      "total": 25
    }
  }
}
```

---

## Strapi Permissions Setup

**IMPORTANT:** Before the frontend can fetch data, you must enable public API access in Strapi.

### Steps:

1. **Login to Strapi Admin:** https://cms.yaicos.com/admin

2. **Go to Settings > Users & Permissions Plugin > Roles**

3. **Click "Public" role**

4. **Enable these permissions for `Yaicos-article`:**
   - ✅ `find` - List articles
   - ✅ `findOne` - Get single article by ID
   - ❌ `create` - Keep disabled (admin only)
   - ❌ `update` - Keep disabled (admin only)
   - ❌ `delete` - Keep disabled (admin only)

5. **Enable these permissions for `Author`:**
   - ✅ `find` - List authors
   - ✅ `findOne` - Get single author

6. **Click "Save"**

### Test API Access

```bash
# Test: Fetch all Yaicos articles
curl https://cms.yaicos.com/api/yaicos-articles?populate=*

# Should return JSON, not 403 Forbidden
```

---

## Usage Examples

### Blog Listing Page

```typescript
import { useYaicosArticles } from "@/hooks/useBlog";
import { getStrapiMedia, formatCategoryName } from "@/lib/strapi";

const BlogPage = () => {
  const [page, setPage] = useState(1);
  const [category, setCategory] = useState<string>();

  const { data, isLoading, error } = useYaicosArticles(page, category);

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;

  const articles = data?.data || [];
  const pagination = data?.meta?.pagination;

  return (
    <div>
      {/* Category Filter */}
      <CategoryFilter
        selected={category}
        onChange={setCategory}
      />

      {/* Articles Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {articles.map((article) => (
          <article key={article.id} className="bg-white rounded-lg shadow-md hover:shadow-lg transition">
            {/* Featured Image */}
            {article.attributes.featured_image?.data && (
              <img
                src={getStrapiMedia(article.attributes.featured_image.data.attributes.url)}
                alt={article.attributes.featured_image.data.attributes.alternativeText}
                className="w-full h-48 object-cover rounded-t-lg"
              />
            )}

            <div className="p-6">
              {/* Category Badge */}
              {article.attributes.category && (
                <span className="text-sm text-orange-600 font-medium">
                  {formatCategoryName(article.attributes.category)}
                </span>
              )}

              {/* Title */}
              <h2 className="text-xl font-bold mt-2 mb-3">
                {article.attributes.title}
              </h2>

              {/* Excerpt */}
              <p className="text-gray-600 mb-4">
                {article.attributes.excerpt}
              </p>

              {/* Author & Date */}
              <div className="flex items-center text-sm text-gray-500">
                {article.attributes.author?.data && (
                  <>
                    {article.attributes.author.data.attributes.avatar?.data && (
                      <img
                        src={getStrapiMedia(
                          article.attributes.author.data.attributes.avatar.data.attributes.url
                        )}
                        alt={article.attributes.author.data.attributes.name}
                        className="w-8 h-8 rounded-full mr-2"
                      />
                    )}
                    <span>{article.attributes.author.data.attributes.name}</span>
                    <span className="mx-2">•</span>
                  </>
                )}
                <time dateTime={article.attributes.publishedAt}>
                  {new Date(article.attributes.publishedAt).toLocaleDateString("es-ES", {
                    year: "numeric",
                    month: "long",
                    day: "numeric",
                  })}
                </time>
              </div>

              {/* Read More Link */}
              <a
                href={`/blog/${article.attributes.slug}`}
                className="mt-4 inline-block text-indigo-600 hover:text-indigo-800 font-medium"
              >
                Leer más →
              </a>
            </div>
          </article>
        ))}
      </div>

      {/* Pagination */}
      {pagination && (
        <Pagination
          currentPage={pagination.page}
          totalPages={pagination.pageCount}
          onPageChange={setPage}
        />
      )}
    </div>
  );
};
```

### Single Article Page

```typescript
import { useYaicosArticle } from "@/hooks/useBlog";
import { getStrapiMedia } from "@/lib/strapi";
import DOMPurify from "dompurify";

const BlogPostPage = () => {
  const { slug } = useParams<{ slug: string }>();
  const { data, isLoading, error } = useYaicosArticle(slug!);

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;

  const article = data?.data?.[0];
  if (!article) return <NotFound />;

  const { attributes } = article;

  // Sanitize HTML content
  const sanitizedContent = DOMPurify.sanitize(attributes.content);

  return (
    <article className="max-w-4xl mx-auto px-4 py-12">
      {/* SEO Meta Tags */}
      <Helmet>
        <title>{attributes.meta_title || attributes.title}</title>
        <meta name="description" content={attributes.meta_description || attributes.excerpt} />
        {attributes.canonical_url && <link rel="canonical" href={attributes.canonical_url} />}
        {attributes.no_index && <meta name="robots" content="noindex" />}

        {/* Open Graph */}
        <meta property="og:title" content={attributes.meta_title || attributes.title} />
        <meta property="og:description" content={attributes.meta_description || attributes.excerpt} />
        <meta property="og:type" content="article" />
        <meta property="article:published_time" content={attributes.publishedAt} />
        {attributes.og_image?.data && (
          <>
            <meta property="og:image" content={getStrapiMedia(attributes.og_image.data.attributes.url)} />
            <meta property="og:image:alt" content={attributes.og_image_alt || attributes.title} />
            <meta property="og:image:width" content={String(attributes.og_image_width)} />
            <meta property="og:image:height" content={String(attributes.og_image_height)} />
          </>
        )}
      </Helmet>

      {/* Featured Image */}
      {attributes.featured_image?.data && (
        <img
          src={getStrapiMedia(attributes.featured_image.data.attributes.url)}
          alt={attributes.featured_image.data.attributes.alternativeText}
          className="w-full h-96 object-cover rounded-lg mb-8"
        />
      )}

      {/* Category */}
      {attributes.category && (
        <span className="inline-block px-3 py-1 bg-orange-100 text-orange-600 rounded-full text-sm font-medium mb-4">
          {formatCategoryName(attributes.category)}
        </span>
      )}

      {/* Title */}
      <h1 className="text-4xl font-bold mb-4">{attributes.title}</h1>

      {/* Author & Date */}
      <div className="flex items-center mb-8 text-gray-600">
        {attributes.author?.data && (
          <>
            {attributes.author.data.attributes.avatar?.data && (
              <img
                src={getStrapiMedia(attributes.author.data.attributes.avatar.data.attributes.url)}
                alt={attributes.author.data.attributes.name}
                className="w-12 h-12 rounded-full mr-3"
              />
            )}
            <div>
              <p className="font-medium text-gray-900">
                {attributes.author.data.attributes.name}
              </p>
              <p className="text-sm">
                <time dateTime={attributes.publishedAt}>
                  {new Date(attributes.publishedAt).toLocaleDateString("es-ES", {
                    year: "numeric",
                    month: "long",
                    day: "numeric",
                  })}
                </time>
              </p>
            </div>
          </>
        )}
      </div>

      {/* Content */}
      <div
        className="prose prose-lg max-w-none"
        dangerouslySetInnerHTML={{ __html: sanitizedContent }}
      />

      {/* AI Generated Badge (Optional) */}
      {attributes.ai_generated && (
        <div className="mt-8 p-4 bg-blue-50 rounded-lg text-sm text-blue-700">
          ℹ️ Este contenido fue generado con asistencia de IA y revisado por nuestro equipo editorial.
        </div>
      )}

      {/* Share Buttons */}
      <ShareButtons
        url={`https://yaicos.com/blog/${attributes.slug}`}
        title={attributes.title}
      />
    </article>
  );
};
```

---

## Common Pitfalls & Solutions

### ❌ Problem: 404 on `/api/articles`
✅ **Solution:** Use `/api/yaicos-articles` (plural with brand prefix)

### ❌ Problem: 403 Forbidden
✅ **Solution:** Enable Public role permissions in Strapi (see above)

### ❌ Problem: Images not loading
✅ **Solution:** Use `getStrapiMedia()` helper to prepend `https://cms.yaicos.com`

### ❌ Problem: Category filter not working
✅ **Solution:** Categories are enum, use `filters[category][$eq]=alojamiento` not relations

### ❌ Problem: Nested populate not working
✅ **Solution:** Use `populate[author][populate][avatar]=*` for nested relations

---

## Testing Checklist

- [ ] Can fetch list of Yaicos articles from `/api/yaicos-articles`
- [ ] Can fetch single article by slug
- [ ] Images load correctly (use `getStrapiMedia()`)
- [ ] Category filter works with enum values
- [ ] Author information displays with avatar
- [ ] SEO meta tags render correctly
- [ ] Open Graph images work (1200x630)
- [ ] Pagination works
- [ ] Mobile responsive
- [ ] Rich text content renders properly (use DOMPurify)

---

## Next Steps

1. **Verify Strapi permissions** - Enable public read access
2. **Test API endpoints** - Use curl/Postman to verify responses
3. **Implement API client** - Create `src/lib/strapi.ts` with corrected endpoints
4. **Build components** - Start with BlogCard, then pages
5. **Test with real data** - Create at least 3 articles in Strapi with images
6. **Add error handling** - Handle empty states, loading, 404s
7. **Optimize images** - Use Strapi's responsive image formats
8. **Add analytics** - Track blog views and popular articles

---

**Questions?** Contact the backend team to:
- Create test articles in Strapi
- Verify permissions are correct
- Get help with API responses

**Documentation References:**
- Strapi REST API Docs: https://docs.strapi.io/dev-docs/api/rest
- Strapi Populate: https://docs.strapi.io/dev-docs/api/rest/populate-select
- Strapi Filters: https://docs.strapi.io/dev-docs/api/rest/filters-locale-publication
