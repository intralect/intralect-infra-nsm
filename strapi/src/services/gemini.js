'use strict';

const { GoogleGenerativeAI } = require('@google/generative-ai');

let geminiClient = null;
let geminiModel = null;

const getModel = () => {
  if (!geminiModel && process.env.GEMINI_API_KEY) {
    geminiClient = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    geminiModel = geminiClient.getGenerativeModel({ model: 'gemini-2.5-flash' });
  }
  return geminiModel;
};

module.exports = {
  async generateContent(prompt) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      return response.text();
    } catch (error) {
      console.error('Gemini Error:', error.message);
      throw error;
    }
  },
  
  async generateSEO(title, content) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');
    
    const prompt = `Generate SEO metadata for this article:
Title: ${title}
Content preview: ${content.substring(0, 500)}

Return ONLY a JSON object with:
- metaTitle (max 60 chars, compelling)
- metaDescription (max 160 chars, includes keywords)

JSON:`;
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const text = response.text();
      
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
      throw new Error('Invalid response format');
    } catch (error) {
      console.error('SEO Generation Error:', error.message);
      throw error;
    }
  },
  
  async generateExcerpt(content, maxLength = 300) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');
    
    const prompt = `Summarize this article in ${maxLength} characters or less. Make it engaging and informative:

${content.substring(0, 2000)}

Summary:`;
    
    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      return response.text().substring(0, maxLength);
    } catch (error) {
      console.error('Excerpt Generation Error:', error.message);
      throw error;
    }
  },
  
  async generateImagePrompt(title, content, brand = {}, category = null, collectionType = null) {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');

    // ═══════════════════════════════════════════════════════════════════════
    // HARD-CODED BRAND SETTINGS - EASY TO EDIT
    // ═══════════════════════════════════════════════════════════════════════
    // Edit these settings to customize image generation for each collection

    const BRAND_SETTINGS = {
      'yaicos-article': {
        brandName: 'Yaicos',
        targetAudience: 'International students aged 18-30 seeking education and career opportunities',
        visualStyle: 'friendly, welcoming, modern, educational, vibrant, aspirational',
        colorPalette: 'bright blues (#2196F3), warm oranges (#FF9800), energetic yellows (#FFC107), white backgrounds',
        includeHumans: true,
        humanRepresentation: 'diverse international students from Asian, African, European, Latin American, and Middle Eastern backgrounds, aged 18-30, shown from behind or at angles (no direct faces), engaged in learning activities, collaborative work, campus life',
        tone: 'friendly and aspirational',
        additionalGuidelines: 'Images should feel welcoming and inspiring. Show diversity and international representation. Include students in realistic educational or campus settings. Focus on connection, learning, and opportunity. Similar to modern educational platforms like Coursera or Duolingo. Avoid stock photo poses - use natural, candid scenarios.',
        avoidElements: 'text, logos, cluttered elements, stock photo poses'
      },

      'amabex-article': {
        brandName: 'Amabex',
        targetAudience: 'Corporate procurement professionals and business decision-makers',
        visualStyle: 'corporate, professional, trustworthy, sophisticated, clean, systematic',
        colorPalette: 'corporate blues (#003D7A, #0066CC), silver/gray accents (#7C8B9C), white, minimal use of color',
        includeHumans: false,
        humanRepresentation: null,
        tone: 'corporate and professional',
        additionalGuidelines: 'Images should convey trust, efficiency, and professionalism. Use abstract representations of procurement processes, supply chains, business networks, or enterprise systems. Focus on structure, data visualization, and systematic approaches. Maintain a serious, corporate aesthetic similar to Fortune 500 companies. Show business workflows, organizational charts, or process diagrams in a clean, modern style.',
        avoidElements: 'text, logos, faces, hands, informal elements, bright colors, consumer imagery'
      },

      'guardscan-article': {
        brandName: 'GuardScan',
        targetAudience: 'IT security professionals, system administrators, CISOs, and cybersecurity teams',
        visualStyle: 'technical, secure, high-tech, cutting-edge, sophisticated, dramatic',
        colorPalette: 'deep blues (#001F3F), cyber green (#00FF41), electric blue (#00D4FF), dark backgrounds (#0A0E27), neon accents',
        includeHumans: false,
        humanRepresentation: null,
        tone: 'technical and cutting-edge',
        additionalGuidelines: 'Images should feel technically sophisticated and cutting-edge. Use advanced visualizations of networks, encryption, data protection, threat detection, and security systems. Include circuit patterns, digital shields, encrypted data streams, network topologies, or security architecture diagrams. Avoid cliché padlock or simple shield imagery. Focus on enterprise-grade security visualization similar to platforms like CrowdStrike, Palo Alto Networks, or high-end SOC (Security Operations Center) environments. Use Matrix-style aesthetics with digital elements.',
        avoidElements: 'text, logos, faces, hands, generic security symbols, consumer-grade imagery, simple padlocks'
      }
    };

    // Get brand settings for this collection, or use defaults
    const settings = BRAND_SETTINGS[collectionType] || {
      brandName: 'the brand',
      targetAudience: 'professional audience',
      visualStyle: 'modern, professional, clean',
      colorPalette: 'vibrant blues, whites, subtle gradients',
      includeHumans: false,
      humanRepresentation: null,
      tone: 'professional',
      additionalGuidelines: '',
      avoidElements: 'text, logos, faces, cluttered elements'
    };

    // Use brand settings
    const {
      style = settings.visualStyle,
      colors = settings.colorPalette,
      avoid = settings.avoidElements,
      composition = 'wide landscape format (16:9), centered subject, professional lighting'
    } = brand;

    const targetAudience = settings.targetAudience;
    const includeHumans = settings.includeHumans;
    const humanRepresentation = settings.humanRepresentation;
    const tone = settings.tone;
    const additionalGuidelines = settings.additionalGuidelines;
    const brandName = settings.brandName;

    // Category-specific visual templates for uniformity
    const categoryTemplates = {
      'technology': 'Futuristic tech environment with glowing interfaces, circuit patterns, or digital networks',
      'ai-machine-learning': 'Neural network visualization, data streams, algorithmic patterns, or AI brain concept',
      'cybersecurity': 'Digital shield, encrypted data visualization, security locks, or network protection concept',
      'business': 'Modern office environment with growth charts, business strategy elements, or professional workspace',
      'marketing': 'Marketing funnel visualization, campaign elements, customer journey map, or brand strategy board',
      'automation': 'Automated workflow system, connected processes, robotic arms, or efficiency visualization',
      'cloud-computing': 'Cloud infrastructure, server networks, distributed systems, or data center visualization',
      'data-analytics': 'Data dashboard, charts and graphs, analytics visualization, or metrics display',
      'software-development': 'Code editor interface, development workflow, programming concepts, or software architecture',
      'e-commerce': 'Digital storefront, shopping cart visualization, online retail elements, or payment systems',
      'productivity': 'Organized workflow, task management board, time optimization, or efficiency tools',
      'social-media': 'Social network visualization, engagement metrics, content distribution, or platform interface',
      'seo-sem': 'Search results visualization, ranking metrics, keyword clouds, or search algorithm concept',
      'default': 'Professional abstract representation of the concept with modern design elements'
    };

    const categoryTemplate = categoryTemplates[category] || categoryTemplates['default'];

    // Build prompt with brand-specific settings
    const humanSection = includeHumans ? `
7. HUMAN REPRESENTATION (REQUIRED):
   - Include ${humanRepresentation}
   - Show people in realistic, engaging scenarios
   - Avoid stock photo poses
   - Make it relatable to ${targetAudience}
   - People should be shown from behind or at angles (no direct face shots)` : '';

    const prompt = `Create a professional blog header image for this specific article:

═══════════════════════════════════════════════════════
BRAND: ${brandName}
TARGET AUDIENCE: ${targetAudience}
TONE: ${tone}
═══════════════════════════════════════════════════════

ARTICLE TITLE (PRIMARY FOCUS): "${title}"
═══════════════════════════════════════════════════════

Category: ${category || 'general'}
Visual Template: ${categoryTemplate}

Content Summary:
${content.substring(0, 800)}

═══════════════════════════════════════════════════════
TASK: Generate DALL-E 3 prompt that directly visualizes the article title
═══════════════════════════════════════════════════════

MANDATORY REQUIREMENTS:

1. TITLE-DRIVEN CONCEPT ⭐ (MOST IMPORTANT)
   - The image MUST visually represent "${title}"
   - Every element should support the title's message
   - Ask: "Does this image immediately convey '${title}'?"
   - Be specific to THIS exact title, not generic to the category

2. CATEGORY VISUAL STYLE (for uniformity):
   - Use this template: ${categoryTemplate}
   - Adapt the template specifically for "${title}"
   - Maintain category consistency while being title-specific

3. STRICT VISUAL STANDARDS (same for ALL images):
   Base Colors: ${colors}
   Style: ${style}
   Composition: ${composition}
   Tone: ${tone}
   Format: Wide landscape (1792x1024), perfect for blog header
   Quality: Photorealistic, editorial-grade, magazine cover quality
   Lighting: Professional studio lighting from upper left at 45°
   Background: Clean gradient, not distracting from subject
   Depth: 3D perspective with layered elements

4. COMPOSITIONAL UNIFORMITY:
   - Central focal point at golden ratio
   - Subject occupies 60-70% of frame
   - Breathing room around edges (10% margin)
   - Horizontal orientation emphasized
   - Professional negative space usage

5. TARGET AUDIENCE CONSIDERATION:
   - Design appeals to: ${targetAudience}
   - Tone should be: ${tone}
   - Brand identity: ${brandName}

6. ABSOLUTE PROHIBITIONS:
   ❌ ${avoid}
   ❌ Any text, numbers, or letters
   ❌ Generic stock imagery
   ${includeHumans ? '⚠️  Show people from behind or at angles (no direct faces)' : '❌ People\'s faces or hands'}
   ❌ Company logos or brands
   ❌ Cliché imagery (handshakes, climbing arrows, lightbulbs)
   ❌ Cluttered or busy compositions
${humanSection}

${additionalGuidelines ? `\n8. ADDITIONAL BRAND GUIDELINES:\n${additionalGuidelines}\n` : ''}

OUTPUT INSTRUCTIONS:
Write a detailed 150-200 word DALL-E 3 prompt that:
- Opens with the main concept directly related to "${title}"
- Describes specific visual elements (not generic)
- Includes exact color codes and composition details
- Appeals to ${targetAudience}
- Maintains ${tone} tone
- Ends with technical specifications

DALL-E 3 Prompt:`;

    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      let imagePrompt = response.text().trim();

      // Remove any markdown formatting
      imagePrompt = imagePrompt.replace(/```.*?\n|```/g, '').trim();

      // Enforce uniformity suffix (same for ALL images)
      const uniformitySuffix = ` | Professional blog header image | 1792x1024 wide landscape | Centered composition with 10% margins | ${colors} color scheme | Clean gradient background | Professional studio lighting from upper-left 45° | High-quality photorealistic render | Modern editorial style | Clean aesthetic | No text, logos, or faces`;

      const finalPrompt = `${imagePrompt}${uniformitySuffix}`;

      return finalPrompt;
    } catch (error) {
      console.error('Image Prompt Error:', error.message);
      throw error;
    }
  },

  async generateBlogDraft(topic, keywords = [], outline = '') {
    const model = getModel();
    if (!model) throw new Error('Gemini not configured');

    const keywordsText = keywords.length > 0 ? `\nKeywords to include: ${keywords.join(', ')}` : '';
    const outlineText = outline ? `\nOutline/Structure: ${outline}` : '';

    const prompt = `Write a comprehensive, engaging blog article on the following topic:

Topic: ${topic}${keywordsText}${outlineText}

Requirements:
- Length: 1200-1500 words minimum
- Structure: Include an introduction, 3-5 main sections with H2 headings, and a conclusion
- Use H3 subheadings where appropriate for better organization
- Write in a professional but conversational tone
- Include practical insights, examples, or actionable takeaways
- Make it SEO-friendly by naturally incorporating keywords
- Use short paragraphs (2-4 sentences) for readability

IMPORTANT: Format the article in HTML with proper semantic tags:
- Use <h2> for main section headings
- Use <h3> for subsection headings
- Use <p> for paragraphs
- Use <ul> and <li> for bullet lists
- Use <strong> for emphasis
- Do NOT include <h1> tags (title is separate)
- Do NOT include <html>, <head>, or <body> tags (content only)

Return only the HTML content, ready to be inserted into a rich text editor.

Article:`;

    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      let htmlContent = response.text();

      // Clean up any markdown artifacts that might slip through
      htmlContent = htmlContent
        .replace(/^#{2,3}\s+/gm, '') // Remove markdown headers
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>') // Convert **bold**
        .replace(/\*(.*?)\*/g, '<em>$1</em>'); // Convert *italic*

      return htmlContent;
    } catch (error) {
      console.error('Blog Draft Error:', error.message);
      throw error;
    }
  },

  isConfigured() {
    return !!process.env.GEMINI_API_KEY;
  },
};
