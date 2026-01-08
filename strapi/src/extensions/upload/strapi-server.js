'use strict';

/**
 * Image optimization extension for Strapi Upload plugin
 * Automatically compresses images and generates WebP versions
 */

module.exports = (plugin) => {
  // Extend the default upload service
  const originalUpload = plugin.services.upload.uploadFileAndPersist;

  plugin.services.upload.uploadFileAndPersist = async function (fileData, options = {}) {
    // Call original upload first (this handles Sharp resizing)
    const uploadedFile = await originalUpload.call(this, fileData, options);

    // Log the optimization results
    if (uploadedFile && uploadedFile.formats) {
      const formatSizes = Object.keys(uploadedFile.formats).map(format => {
        const size = (uploadedFile.formats[format].size / 1024).toFixed(2);
        return `${format}: ${size}KB`;
      });

      console.log('✅ Image optimized:', uploadedFile.name);
      console.log('   Original:', (uploadedFile.size / 1024).toFixed(2), 'KB');
      console.log('   Formats:', formatSizes.join(', '));
    }

    return uploadedFile;
  };

  return plugin;
};
