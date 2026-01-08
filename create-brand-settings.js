// Script to create initial brand settings for each collection
// Run this from the Strapi directory: node ../create-brand-settings.js

const brandSettings = [
  {
    collection_name: 'yaicos-article',
    brand_name: 'Yaicos',
    target_audience: 'International students seeking education and career opportunities',
    visual_style: 'friendly, modern, educational, vibrant',
    color_palette: 'bright blues (#2196F3), warm oranges (#FF9800), energetic yellows, white backgrounds',
    include_humans: true,
    human_representation: 'diverse international students, young people aged 18-30, multicultural backgrounds, engaging in learning and collaboration',
    tone: 'friendly',
    custom_prompt_template: null,
    avoid_elements: 'text, logos, cluttered elements',
    composition_rules: 'wide landscape format (16:9), centered subject with people interacting, bright natural lighting',
    additional_guidelines: 'Images should feel welcoming and aspirational. Show diversity and international representation. Include students in realistic educational or campus settings. Focus on connection, learning, and opportunity. Reference the warm, inclusive style similar to modern educational platforms.',
    reference_image_url: null,
    active: true
  },
  {
    collection_name: 'amabex-article',
    brand_name: 'Amabex',
    target_audience: 'Corporate procurement professionals and business decision-makers',
    visual_style: 'corporate, professional, trustworthy, sophisticated',
    color_palette: 'corporate blues (#003D7A, #0066CC), silver/gray accents (#7C8B9C), white, minimal color',
    include_humans: false,
    human_representation: null,
    tone: 'corporate',
    custom_prompt_template: null,
    avoid_elements: 'text, logos, faces, informal elements, bright colors',
    composition_rules: 'wide landscape format (16:9), clean centered composition, professional studio lighting, emphasis on structure and organization',
    additional_guidelines: 'Images should convey trust, efficiency, and professionalism. Use abstract representations of procurement processes, supply chains, business networks, or enterprise systems. Focus on structure, data, and systematic approaches. Maintain a serious, corporate aesthetic similar to Fortune 500 company imagery.',
    reference_image_url: null,
    active: true
  },
  {
    collection_name: 'guardscan-article',
    brand_name: 'GuardScan',
    target_audience: 'IT security professionals, system administrators, cybersecurity teams',
    visual_style: 'technical, secure, high-tech, cutting-edge',
    color_palette: 'deep blues (#001F3F), cyber green (#00FF41), dark backgrounds, neon accents',
    include_humans: false,
    human_representation: null,
    tone: 'technical',
    custom_prompt_template: null,
    avoid_elements: 'text, logos, faces, generic security symbols, consumer-grade imagery',
    composition_rules: 'wide landscape format (16:9), centered technical visualization, dramatic lighting with blue/green accents, high-tech atmosphere',
    additional_guidelines: 'Images should feel cutting-edge and technically sophisticated. Use advanced visualizations of networks, encryption, data protection, threat detection, and security systems. Include circuit patterns, digital shields, encrypted data streams, or security architecture. Avoid cliché padlock imagery. Focus on enterprise-grade security visualization similar to high-end cybersecurity platforms.',
    reference_image_url: null,
    active: true
  }
];

console.log('Brand Settings to Create:');
console.log(JSON.stringify(brandSettings, null, 2));
console.log('\n\nTo create these settings:');
console.log('1. Go to Strapi Admin: https://cms.yaicos.com/admin');
console.log('2. Go to Content Manager > Brand Settings');
console.log('3. Create three new entries using the data above');
console.log('\nOr use the Strapi API to create them programmatically.');
