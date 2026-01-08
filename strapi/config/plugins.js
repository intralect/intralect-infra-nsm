module.exports = ({ env }) => ({
  // Upload plugin - Image optimization
  upload: {
    config: {
      // Strapi keeps the original file and generates optimized versions
      sizeLimit: 10 * 1024 * 1024, // 10MB max upload size

      // Responsive image breakpoints
      // Strapi will automatically generate these sizes using Sharp
      breakpoints: {
        xlarge: 1920,  // For full-screen displays
        large: 1000,   // For blog headers (your AI images)
        medium: 750,   // For tablets/mobile
        small: 500,    // For mobile thumbnails
        xsmall: 64,    // For tiny previews
      },

      // Image quality settings for Sharp
      // These apply to all generated formats
      quality: 80, // Default quality (80 = good balance)
      progressive: true, // Progressive JPEG (loads faster)

      // Enable automatic WebP generation (much smaller files)
      generateWebP: true, // If this option exists in your Strapi version
    },
  },

  // Scheduler plugin - Schedule publish/unpublish dates
  'scheduler': {
    enabled: true,
  },
});
