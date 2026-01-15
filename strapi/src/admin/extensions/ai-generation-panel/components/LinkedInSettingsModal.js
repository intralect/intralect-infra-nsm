import React, { useState, useEffect } from 'react';
import {
  ModalLayout,
  ModalHeader,
  ModalBody,
  ModalFooter,
} from '@strapi/design-system/ModalLayout';
import { Button } from '@strapi/design-system/Button';
import { Typography } from '@strapi/design-system/Typography';
import { TextInput } from '@strapi/design-system/TextInput';
import { Box } from '@strapi/design-system/Box';
import { Stack } from '@strapi/design-system/Stack';
import { Alert } from '@strapi/design-system/Alert';
import { useNotification } from '@strapi/helper-plugin';
import { Check, ExclamationMarkCircle, Information } from '@strapi/icons';

const LinkedInSettingsModal = ({ isOpen, onClose }) => {
  const [loading, setLoading] = useState(false);
  const [validating, setValidating] = useState(false);
  const [clientId, setClientId] = useState('');
  const [clientSecret, setClientSecret] = useState('');
  const [accessToken, setAccessToken] = useState('');
  const [organizationId, setOrganizationId] = useState('');
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);
  const [isConfigured, setIsConfigured] = useState(false);
  const toggleNotification = useNotification();

  // Load existing settings when modal opens
  useEffect(() => {
    if (isOpen) {
      loadSettings();
    }
  }, [isOpen]);

  const loadSettings = async () => {
    try {
      const response = await fetch('/api/linkedin/settings');
      if (response.ok) {
        const data = await response.json();
        setClientId(data.clientId || '');
        setIsConfigured(data.isConfigured || false);
        // Show masked token as placeholder if configured
        setAccessToken('');
        setOrganizationId(data.organizationId || '');

        // Show token status in UI
        if (data.accessTokenMasked) {
          toggleNotification({
            type: 'success',
            message: `Access token is configured (${data.accessTokenMasked})`,
          });
        }
      }
    } catch (err) {
      console.error('Failed to load settings:', err);
    }
  };

  const handleSave = async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/linkedin/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clientId,
          clientSecret: clientSecret || undefined, // Only update if provided
          accessToken: accessToken || undefined, // Only update if provided
          organizationId: organizationId || undefined,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to save settings');
      }

      setSuccess(true);
      toggleNotification({
        type: 'success',
        message: 'LinkedIn credentials saved successfully!',
      });

      // Validate credentials after saving
      await validateCredentials();

      setTimeout(() => {
        setSuccess(false);
        onClose();
      }, 2000);
    } catch (err) {
      setError(err.message);
      toggleNotification({
        type: 'warning',
        message: `Failed to save credentials: ${err.message}`,
      });
    } finally {
      setLoading(false);
    }
  };

  const validateCredentials = async () => {
    setValidating(true);
    try {
      const response = await fetch('/api/linkedin/validate');
      const data = await response.json();

      if (data.valid) {
        toggleNotification({
          type: 'success',
          message: 'LinkedIn credentials are valid!',
        });
        setIsConfigured(true);
      } else {
        toggleNotification({
          type: 'warning',
          message: 'LinkedIn credentials are invalid or expired',
        });
        setIsConfigured(false);
      }
    } catch (err) {
      console.error('Validation error:', err);
    } finally {
      setValidating(false);
    }
  };

  if (!isOpen) return null;

  return (
    <ModalLayout onClose={onClose} labelledBy="linkedin-settings-modal">
      <ModalHeader>
        <Typography fontWeight="bold" textColor="neutral800" as="h2" id="linkedin-settings-modal">
          LinkedIn API Settings
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
              Settings saved successfully!
            </Alert>
          )}

          {isConfigured && (
            <Alert
              closeLabel="Close"
              variant="success"
              icon={<Information />}
            >
              LinkedIn is configured and ready to use
            </Alert>
          )}

          <TextInput
            label="Client ID"
            placeholder="Enter your LinkedIn Client ID"
            value={clientId}
            onChange={(e) => setClientId(e.target.value)}
            disabled={loading || success}
            required
          />

          <TextInput
            label="Client Secret"
            placeholder={isConfigured ? "Leave empty to keep current secret" : "Enter your LinkedIn Client Secret"}
            value={clientSecret}
            onChange={(e) => setClientSecret(e.target.value)}
            disabled={loading || success}
            type="password"
            hint={isConfigured ? "Secret is configured. Enter a new secret to update." : "Required for OAuth 2.0"}
            required={!isConfigured}
          />

          <Box padding={3} background="primary100" hasRadius>
            <Stack spacing={2}>
              <Typography variant="omega" fontWeight="semiBold">
                Easy Setup: Connect with LinkedIn OAuth 2.0
              </Typography>
              <Typography variant="pi" textColor="neutral600">
                After entering your Client ID and Client Secret above, click "Save Settings" first, then click the button below to automatically get your access token.
              </Typography>
              <Button
                variant="secondary"
                fullWidth
                disabled={!clientId || !clientSecret}
                onClick={() => {
                  window.open('/api/linkedin/oauth/authorize', '_blank', 'width=600,height=700');
                }}
              >
                Connect with LinkedIn OAuth
              </Button>
            </Stack>
          </Box>

          <TextInput
            label="Access Token (Optional - Use OAuth instead)"
            placeholder={isConfigured ? "Token configured via OAuth" : "Or manually paste access token"}
            value={accessToken}
            onChange={(e) => setAccessToken(e.target.value)}
            disabled={loading || success}
            type="password"
            hint={isConfigured ? "Token is configured. Use OAuth button above to refresh." : "Use OAuth button above (recommended) or manually paste token"}
          />

          <TextInput
            label="Organization ID (Optional)"
            placeholder="Enter Organization ID for company page posting"
            value={organizationId}
            onChange={(e) => setOrganizationId(e.target.value)}
            disabled={loading || success}
            hint="Leave empty for personal profile posting"
          />

          <Box padding={3} background="neutral100" hasRadius>
            <Typography variant="omega" textColor="neutral600">
              <strong>How to get LinkedIn API credentials:</strong>
              <br />
              1. Go to <a href="https://www.linkedin.com/developers/apps" target="_blank" rel="noopener">LinkedIn Developer Portal</a>
              <br />
              2. Create a new app (or select existing)
              <br />
              3. Copy your Client ID and Client Secret
              <br />
              4. Add this Redirect URL: <code>https://cms.yaicos.com/api/linkedin/oauth/callback</code>
              <br />
              5. Enable these permissions: "Sign in with LinkedIn" + "Share on LinkedIn"
              <br />
              6. Paste Client ID and Client Secret above, save, then use OAuth button
            </Typography>
          </Box>
        </Stack>
      </ModalBody>

      <ModalFooter
        startActions={
          <Button onClick={onClose} variant="tertiary" disabled={loading}>
            Cancel
          </Button>
        }
        endActions={
          <Stack horizontal spacing={2}>
            {isConfigured && (
              <Button
                onClick={validateCredentials}
                variant="secondary"
                disabled={loading || validating}
                loading={validating}
              >
                Test Connection
              </Button>
            )}
            <Button
              onClick={handleSave}
              variant="success"
              disabled={!clientId || loading || success}
              loading={loading}
            >
              {success ? 'Saved!' : 'Save Settings'}
            </Button>
          </Stack>
        }
      />
    </ModalLayout>
  );
};

export default LinkedInSettingsModal;
