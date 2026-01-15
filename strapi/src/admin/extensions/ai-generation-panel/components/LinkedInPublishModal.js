import React, { useState, useEffect } from 'react';
import {
  ModalLayout,
  ModalHeader,
  ModalBody,
  ModalFooter,
} from '@strapi/design-system/ModalLayout';
import { Button } from '@strapi/design-system/Button';
import { Typography } from '@strapi/design-system/Typography';
import { Textarea } from '@strapi/design-system/Textarea';
import { Box } from '@strapi/design-system/Box';
import { Stack } from '@strapi/design-system/Stack';
import { Loader } from '@strapi/design-system/Loader';
import { Alert } from '@strapi/design-system/Alert';
import { useNotification } from '@strapi/helper-plugin';
import { Check, ExclamationMarkCircle } from '@strapi/icons';

const LinkedInPublishModal = ({ isOpen, onClose, article, articleUrl }) => {
  const [loading, setLoading] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [postText, setPostText] = useState('');
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);
  const toggleNotification = useNotification();

  // Don't auto-generate on open - let user paste or click generate
  // useEffect(() => {
  //   if (isOpen && article && !postText) {
  //     generatePost();
  //   }
  // }, [isOpen, article]);

  const generatePost = async () => {
    setGenerating(true);
    setError(null);

    try {
      const response = await fetch('/api/linkedin/generate-post', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: article.title || '',
          excerpt: article.excerpt || '',
          content: article.content || '',
          articleUrl: articleUrl || '',
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to generate LinkedIn post');
      }

      const data = await response.json();
      setPostText(data.postText);
    } catch (err) {
      setError(err.message);
      toggleNotification({
        type: 'warning',
        message: 'Failed to generate LinkedIn post. Please write one manually.',
      });
    } finally {
      setGenerating(false);
    }
  };

  const handlePublish = async () => {
    setLoading(true);
    setError(null);

    try {
      const ogImageUrl = article.og_image?.url || article.featured_image?.url;

      const response = await fetch('/api/linkedin/publish', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          articleId: article.id,
          postText: postText,
          articleUrl: articleUrl,
          imageUrl: ogImageUrl ? `${window.location.origin}${ogImageUrl}` : null,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error?.message || 'Failed to publish to LinkedIn');
      }

      const data = await response.json();
      setSuccess(true);

      toggleNotification({
        type: 'success',
        message: 'Successfully published to LinkedIn!',
      });

      // Close modal after 2 seconds
      setTimeout(() => {
        onClose();
        setPostText('');
        setSuccess(false);
      }, 2000);
    } catch (err) {
      setError(err.message);
      toggleNotification({
        type: 'warning',
        message: `LinkedIn publishing failed: ${err.message}`,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    setPostText('');
    setError(null);
    setSuccess(false);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <ModalLayout onClose={handleClose} labelledBy="linkedin-publish-modal">
      <ModalHeader>
        <Typography fontWeight="bold" textColor="neutral800" as="h2" id="linkedin-publish-modal">
          Publish to LinkedIn
        </Typography>
      </ModalHeader>

      <ModalBody>
        <Stack spacing={4}>
          {error && (
            <Alert
              closeLabel="Close"
              variant="danger"
              icon={<ExclamationMarkCircle />}
            >
              {error}
            </Alert>
          )}

          {success && (
            <Alert
              closeLabel="Close"
              variant="success"
              icon={<Check />}
            >
              Successfully published to LinkedIn!
            </Alert>
          )}

          <Box>
            <Typography variant="beta" fontWeight="semiBold">
              Article: {article?.title}
            </Typography>
            <Typography variant="pi" textColor="neutral600">
              {articleUrl}
            </Typography>
          </Box>

          {generating ? (
            <Box padding={4} background="neutral100" hasRadius>
              <Stack horizontal spacing={2} justifyContent="center">
                <Loader small>Generating LinkedIn post...</Loader>
                <Typography>Generating LinkedIn post...</Typography>
              </Stack>
            </Box>
          ) : (
            <Textarea
              label="LinkedIn Post"
              placeholder="Paste your post here or click 'Generate with AI' below..."
              value={postText}
              onChange={(e) => setPostText(e.target.value)}
              hint="Paste your own post or generate one with AI. Edit as needed before publishing."
              disabled={loading || success}
            >
              {postText}
            </Textarea>
          )}

          <Box padding={3} background="neutral100" hasRadius>
            <Typography variant="pi" textColor="neutral600">
              <strong>Tone Guide (Option C):</strong> Professional but Approachable
              <br />
              • Hook: Hard fact or pain point
              <br />
              • Insight: Why it matters
              <br />
              • CTA: Clear call to action
              <br />
              • 1-2 relevant emojis (🏭 📊 💼 🔍)
            </Typography>
          </Box>
        </Stack>
      </ModalBody>

      <ModalFooter
        startActions={
          <Button onClick={handleClose} variant="tertiary" disabled={loading}>
            Cancel
          </Button>
        }
        endActions={
          <Stack horizontal spacing={2}>
            <Button
              onClick={generatePost}
              variant="secondary"
              disabled={loading || generating || success}
            >
              {postText ? 'Regenerate with AI' : 'Generate with AI'}
            </Button>
            <Button
              onClick={handlePublish}
              variant="success"
              disabled={!postText || loading || generating || success}
              loading={loading}
            >
              {success ? 'Published!' : 'Publish to LinkedIn'}
            </Button>
          </Stack>
        }
      />
    </ModalLayout>
  );
};

export default LinkedInPublishModal;
