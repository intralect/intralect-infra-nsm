import React, { useState } from 'react';
import { useCMEditViewDataManager } from '@strapi/helper-plugin';
import { Box } from '@strapi/design-system/Box';
import { Typography } from '@strapi/design-system/Typography';
import { Stack } from '@strapi/design-system/Stack';
import { Divider } from '@strapi/design-system/Divider';
import { Magic } from '@strapi/icons';
import AIButton from './AIButton';
import BlogDraftModal from './BlogDraftModal';
import ImageModal from './ImageModal';

const AIGenerationPanel = () => {
  const { modifiedData, onChange, slug } = useCMEditViewDataManager();
  const [blogDraftModalOpen, setBlogDraftModalOpen] = useState(false);
  const [imageModalOpen, setImageModalOpen] = useState(false);
  const [imageData, setImageData] = useState({ url: '', prompt: '' });
  const [draftLoading, setDraftLoading] = useState(false);

  // Only show for article content types
  const isArticleType = slug && (
    slug === 'api::yaicos-article.yaicos-article' ||
    slug === 'api::guardscan-article.guardscan-article' ||
    slug === 'api::amabex-article.amabex-article'
  );

  if (!isArticleType) {
    return null;
  }

  // Determine collection type for brand-specific image generation
  const getCollectionType = () => {
    if (slug === 'api::yaicos-article.yaicos-article') return 'yaicos-article';
    if (slug === 'api::guardscan-article.guardscan-article') return 'guardscan-article';
    if (slug === 'api::amabex-article.amabex-article') return 'amabex-article';
    return null;
  };

  // Extract current field values
  const { title, content, excerpt, meta_title, meta_description, category } = modifiedData || {};

  // Handler to update form fields
  const updateField = (fieldName, value) => {
    onChange({
      target: {
        name: fieldName,
        type: 'text',
        value: value,
      },
    });
  };

  // Handle blog draft generation
  const handleBlogDraftGenerate = async ({ topic, keywords, outline }) => {
    setDraftLoading(true);
    try {
      const response = await fetch('/api/ai/generate-blog-draft', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ topic, keywords, outline }),
      });

      if (!response.ok) {
        throw new Error('Failed to generate blog draft');
      }

      const data = await response.json();

      // Update title and content fields
      if (!title) {
        updateField('title', topic);
      }
      updateField('content', data.content);

      setBlogDraftModalOpen(false);
    } catch (error) {
      console.error('Blog draft generation error:', error);
    } finally {
      setDraftLoading(false);
    }
  };

  return (
    <>
      <Box
        background="neutral0"
        padding={4}
        hasRadius
        shadow="filterShadow"
      >
        <Stack spacing={3}>
          <Box paddingBottom={2}>
            <Typography variant="sigma" textColor="neutral600">
              <Magic style={{ marginRight: '8px', verticalAlign: 'middle' }} />
              AI Content Generation
            </Typography>
          </Box>

          <Divider />

          {/* Blog Draft Generation */}
          <AIButton
            label="Generate Blog Draft"
            endpoint="#"
            payload={{}}
            onSuccess={() => {}}
            disabled={false}
            onClick={() => setBlogDraftModalOpen(true)}
          />

          <Divider />

          {/* SEO Generation */}
          <AIButton
            label="Generate SEO Metadata"
            endpoint="/api/ai/generate-seo"
            payload={{ title: title || '', content: content || '' }}
            onSuccess={(data) => {
              if (data.metaTitle) {
                updateField('meta_title', data.metaTitle);
              }
              if (data.metaDescription) {
                updateField('meta_description', data.metaDescription);
              }
            }}
            disabled={!title || !content}
          />

          {/* Excerpt Generation */}
          <AIButton
            label="Generate Excerpt"
            endpoint="/api/ai/generate-excerpt"
            payload={{ content: content || '', maxLength: 300 }}
            onSuccess={(data) => {
              if (data.excerpt) {
                updateField('excerpt', data.excerpt);
              }
            }}
            disabled={!content}
          />

          {/* Image Generation */}
          <AIButton
            label="Generate Featured Image"
            endpoint="/api/ai/generate-image"
            payload={{
              title: title || '',
              content: content || '',
              category: category || null,
              collectionType: getCollectionType(), // Pass collection type for brand-specific prompts
              brand: {
                style: 'modern, professional, clean',
                colors: 'vibrant blues, whites, subtle gradients',
                avoid: 'text, logos, faces, cluttered elements',
                composition: 'wide landscape format (16:9), centered subject, professional lighting',
              },
            }}
            onSuccess={(data) => {
              if (data.imageUrl) {
                setImageData({ url: data.imageUrl, prompt: data.prompt });
                setImageModalOpen(true);
              }
            }}
            disabled={!title}
          />

          <Box paddingTop={2}>
            <Typography variant="pi" textColor="neutral500">
              Start by generating a blog draft, then use AI to create SEO metadata, excerpts, and images.
            </Typography>
          </Box>
        </Stack>
      </Box>

      {/* Modals */}
      <BlogDraftModal
        isOpen={blogDraftModalOpen}
        onClose={() => setBlogDraftModalOpen(false)}
        onGenerate={handleBlogDraftGenerate}
        loading={draftLoading}
      />

      <ImageModal
        isOpen={imageModalOpen}
        onClose={() => setImageModalOpen(false)}
        imageUrl={imageData.url}
        prompt={imageData.prompt}
      />
    </>
  );
};

export default AIGenerationPanel;
