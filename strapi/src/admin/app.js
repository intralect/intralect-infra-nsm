import React from 'react';

const config = {
  locales: [],
};

const bootstrap = (app) => {
  // Inject AI Generation Panel into Content Manager Edit View
  app.injectContentManagerComponent('editView', 'informations', {
    name: 'ai-generation-panel',
    Component: React.lazy(() => import('./extensions/ai-generation-panel'))
  });
};

export default {
  config,
  bootstrap,
};
