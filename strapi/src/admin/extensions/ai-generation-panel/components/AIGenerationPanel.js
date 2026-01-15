import React, { useState } from 'react';
import { useCMEditViewDataManager } from '@strapi/helper-plugin';
import { Box } from '@strapi/design-system/Box';
import { Typography } from '@strapi/design-system/Typography';
import { Stack } from '@strapi/design-system/Stack';
import { Divider } from '@strapi/design-system/Divider';
import { Button } from '@strapi/design-system/Button';
import { ToggleInput } from '@strapi/design-system/ToggleInput';
import { Magic, Link, Cog } from '@strapi/icons';
import AIButton from './AIButton';
import BlogDraftModal from './BlogDraftModal';
import ImageModal from './ImageModal';
import LinkedInPublishModal from './LinkedInPublishModal';
import LinkedInSettingsModal from './LinkedInSettingsModal';

const AIGenerationPanel = () => {
  const { modifiedData, onChange, slug } = useCMEditViewDataManager();
  const [blogDraftModalOpen, setBlogDraftModalOpen] = useState(false);
  const [imageModalOpen, setImageModalOpen] = useState(false);
  const [imageData, setImageData] = useState({ url: '', prompt: '', method: '', isBase64: false, fallback: false });
  const [draftLoading, setDraftLoading] = useState(false);
  const [linkedInPublishModalOpen, setLinkedInPublishModalOpen] = useState(false);
  const [linkedInSettingsModalOpen, setLinkedInSettingsModalOpen] = useState(false);

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
  const { title, content, excerpt, meta_title, meta_description, category, auto_publish_to_linkedin, id } = modifiedData || {};

  // Check if this is an Amabex article (LinkedIn only for Amabex)
  const isAmabexArticle = slug === 'api::amabex-article.amabex-article';

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
              // Handle both DALL-E 3 (imageUrl) and Gemini (imageBase64) formats
              if (data.imageUrl) {
                // DALL-E 3 format
                setImageData({
                  url: data.imageUrl,
                  prompt: data.prompt,
                  method: data.method,
                  fallback: data.fallback,
                  collectionType: getCollectionType()
                });
                setImageModalOpen(true);
              } else if (data.imageBase64) {
                // Gemini format - convert base64 to data URL
                const dataUrl = `data:${data.mimeType};base64,${data.imageBase64}`;
                setImageData({
                  url: dataUrl,
                  prompt: data.prompt,
                  method: data.method,
                  isBase64: true,
                  collectionType: getCollectionType()
                });
                setImageModalOpen(true);
              }
            }}
            disabled={!title}
          />

          {/* LinkedIn Publishing (Amabex only) */}
          {isAmabexArticle && (
            <>
              <Divider />

              <Box>
                <Stack spacing={2}>
                  <Box paddingBottom={1}>
                    <Typography variant="sigma" textColor="neutral600">
                      <Link style={{ marginRight: '8px', verticalAlign: 'middle' }} />
                      LinkedIn Publishing
                    </Typography>
                  </Box>

                  <ToggleInput
                    label="Auto-publish to LinkedIn when scheduled"
                    checked={auto_publish_to_linkedin || false}
                    onChange={() => updateField('auto_publish_to_linkedin', !auto_publish_to_linkedin)}
                    hint="Automatically post to LinkedIn when publishAt date is reached"
                  />

                  <Stack horizontal spacing={2}>
                    <Button
                      variant="secondary"
                      startIcon={<Link />}
                      onClick={() => setLinkedInPublishModalOpen(true)}
                      disabled={!title || !id}
                      fullWidth
                    >
                      Publish to LinkedIn
                    </Button>

                    <Button
                      variant="tertiary"
                      startIcon={<Cog />}
                      onClick={() => setLinkedInSettingsModalOpen(true)}
                    >
                      Settings
                    </Button>
                  </Stack>

                  <Typography variant="pi" textColor="neutral500">
                    Generate AI-powered LinkedIn posts with professional tone and relevant emojis.
                  </Typography>
                </Stack>
              </Box>
            </>
          )}

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
        method={imageData.method}
        isBase64={imageData.isBase64}
        fallback={imageData.fallback}
        collectionType={imageData.collectionType}
      />

      {isAmabexArticle && (
        <>
          <LinkedInPublishModal
            isOpen={linkedInPublishModalOpen}
            onClose={() => setLinkedInPublishModalOpen(false)}
            article={modifiedData}
            articleUrl={`https://ambaex.com/blog/${modifiedData?.slug || ''}`}
          />

          <LinkedInSettingsModal
            isOpen={linkedInSettingsModalOpen}
            onClose={() => setLinkedInSettingsModalOpen(false)}
          />
        </>
      )}
    </>
  );
};

export default AIGenerationPanel;
