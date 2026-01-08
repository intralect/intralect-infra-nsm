import { useState } from 'react';
import { useNotification } from '@strapi/helper-plugin';

export const useAIGeneration = () => {
  const [loading, setLoading] = useState(false);
  const toggleNotification = useNotification();

  const generate = async (endpoint, payload, onSuccess) => {
    setLoading(true);

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error?.message || error.message || 'Generation failed');
      }

      const data = await response.json();

      if (onSuccess) {
        onSuccess(data);
      }

      toggleNotification({
        type: 'success',
        message: 'AI generation successful!',
      });

      return data;
    } catch (error) {
      console.error('AI Generation Error:', error);
      toggleNotification({
        type: 'warning',
        message: error.message || 'Failed to generate content',
      });
      throw error;
    } finally {
      setLoading(false);
    }
  };

  return { generate, loading };
};
