import React from 'react';
import { Button } from '@strapi/design-system/Button';
import { Loader } from '@strapi/design-system/Loader';
import { Magic } from '@strapi/icons';
import { useNotification } from '@strapi/helper-plugin';
import { useAIGeneration } from '../hooks/useAIGeneration';

const AIButton = ({ label, endpoint, payload, onSuccess, disabled, fullWidth = true, onClick }) => {
  const { generate, loading } = useAIGeneration();
  const toggleNotification = useNotification();

  const handleGenerate = async () => {
    // If custom onClick handler is provided, use it instead
    if (onClick) {
      onClick();
      return;
    }

    // Validate required fields
    if (!payload.title && !payload.content) {
      toggleNotification({
        type: 'warning',
        message: 'Please add a title and content first',
      });
      return;
    }

    try {
      await generate(endpoint, payload, onSuccess);
    } catch (error) {
      // Error already handled in useAIGeneration hook
      console.error('Generation failed:', error);
    }
  };

  return (
    <Button
      onClick={handleGenerate}
      loading={loading}
      disabled={disabled || loading}
      startIcon={loading ? <Loader small /> : <Magic />}
      variant="secondary"
      fullWidth={fullWidth}
      size="S"
    >
      {label}
    </Button>
  );
};

export default AIButton;
