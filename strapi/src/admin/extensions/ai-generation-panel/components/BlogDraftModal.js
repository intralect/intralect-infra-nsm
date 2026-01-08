import React, { useState } from 'react';
import {
  ModalLayout,
  ModalHeader,
  ModalBody,
  ModalFooter,
} from '@strapi/design-system/ModalLayout';
import { Button } from '@strapi/design-system/Button';
import { Typography } from '@strapi/design-system/Typography';
import { Stack } from '@strapi/design-system/Stack';
import { TextInput } from '@strapi/design-system/TextInput';
import { Textarea } from '@strapi/design-system/Textarea';
import { Loader } from '@strapi/design-system/Loader';
import { Magic } from '@strapi/icons';

const BlogDraftModal = ({ isOpen, onClose, onGenerate, loading }) => {
  const [topic, setTopic] = useState('');
  const [keywords, setKeywords] = useState('');
  const [outline, setOutline] = useState('');

  if (!isOpen) return null;

  const handleGenerate = () => {
    const keywordsArray = keywords
      .split(',')
      .map((k) => k.trim())
      .filter(Boolean);

    onGenerate({
      topic: topic.trim(),
      keywords: keywordsArray,
      outline: outline.trim(),
    });
  };

  const handleClose = () => {
    setTopic('');
    setKeywords('');
    setOutline('');
    onClose();
  };

  const isDisabled = !topic.trim() || loading;

  return (
    <ModalLayout onClose={handleClose} labelledBy="blog-draft-modal-title">
      <ModalHeader>
        <Typography fontWeight="bold" textColor="neutral800" as="h2" id="blog-draft-modal-title">
          Generate Blog Draft
        </Typography>
      </ModalHeader>

      <ModalBody>
        <Stack spacing={4}>
          {/* Topic Input */}
          <TextInput
            label="Topic or Title"
            name="topic"
            placeholder="e.g., Best Marketing Tools 2026"
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
            required
            hint="Enter the main topic or title for your blog article"
          />

          {/* Keywords Input */}
          <TextInput
            label="Keywords (Optional)"
            name="keywords"
            placeholder="e.g., marketing, automation, tools"
            value={keywords}
            onChange={(e) => setKeywords(e.target.value)}
            hint="Comma-separated keywords to include in the article"
          />

          {/* Outline Input */}
          <Textarea
            label="Outline or Structure (Optional)"
            name="outline"
            placeholder="e.g., Introduction, Top 5 Tools, How to Choose, Pricing Comparison, Conclusion"
            value={outline}
            onChange={(e) => setOutline(e.target.value)}
            hint="Provide a rough outline or structure for the article"
          >
            {outline}
          </Textarea>

          {/* Info Box */}
          <Typography variant="pi" textColor="neutral600">
            The AI will generate a comprehensive 1200+ word article with proper structure, headings, and engaging content based on your inputs.
          </Typography>
        </Stack>
      </ModalBody>

      <ModalFooter
        startActions={
          <Button onClick={handleClose} variant="tertiary" disabled={loading}>
            Cancel
          </Button>
        }
        endActions={
          <Button
            onClick={handleGenerate}
            disabled={isDisabled}
            loading={loading}
            startIcon={loading ? <Loader small /> : <Magic />}
          >
            Generate Article
          </Button>
        }
      />
    </ModalLayout>
  );
};

export default BlogDraftModal;
