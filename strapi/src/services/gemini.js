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
        visualStyle: 'PROFESSIONAL DOCUMENTARY PHOTOGRAPHY - friendly, welcoming, modern, educational, vibrant, aspirational',
        colorPalette: 'bright blues (#2196F3), warm oranges (#FF9800), energetic yellows (#FFC107), natural daylight, white backgrounds',
        includeHumans: true,
        humanRepresentation: 'REAL diverse international students from Asian, African, European, Latin American, and Middle Eastern backgrounds, aged 18-30, captured in authentic documentary photography style, shown from behind or at angles (no direct faces), engaged in learning activities, collaborative work, campus life, genuine candid moments',
        tone: 'friendly and aspirational',
        additionalGuidelines: 'CRITICAL: Use PROFESSIONAL PHOTOGRAPHY ONLY - shot on Canon EOS R5 or Nikon Z9, documentary/photojournalism style. Images should feel welcoming and inspiring. Show diversity and international representation with REAL HUMANS in authentic educational or campus settings. Focus on connection, learning, and opportunity. Capture genuine candid moments like street photography or documentary style. Natural lighting, real environments, authentic expressions. STRICTLY AVOID: cartoon style, illustrations, 3D renders, CGI, animated look, artificial appearance. This must look like professional photography you would see in National Geographic or TIME Magazine education features.',
        avoidElements: 'text, logos, cluttered elements, stock photo poses, cartoon style, illustrations, 3D renders, CGI, animated look, plastic appearance'
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
   Quality: PROFESSIONAL PHOTOGRAPHY - Real humans, real locations, editorial-grade
   Photography Style: Shot on professional DSLR camera (Canon EOS R5, 35mm lens, f/2.8)
   Lighting: Natural daylight with soft diffused lighting, golden hour warmth
   Background: Real environment or subtle bokeh blur, authentic setting
   People: REAL HUMANS in natural poses, genuine expressions, documentary style
   ❌ STRICTLY AVOID: Cartoon style, illustrations, 3D renders, CGI, animated look, artificial/plastic appearance

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
   ❌ CARTOON STYLE - No cartoons, animations, illustrations, comic book style
   ❌ 3D RENDERS - No CGI, 3D graphics, computer-generated imagery, artificial look
   ❌ ILLUSTRATED ART - No drawn, painted, or illustrated style
   ❌ ANIMATED APPEARANCE - No plastic/toy-like appearance, no unrealistic skin tones
   ✅ ONLY REAL PHOTOGRAPHY - Professional DSLR photography of real humans and real environments
${humanSection}

${additionalGuidelines ? `\n8. ADDITIONAL BRAND GUIDELINES:\n${additionalGuidelines}\n` : ''}

OUTPUT INSTRUCTIONS:
Write a detailed 150-200 word DALL-E 3 prompt that:
- Opens with the main concept directly related to "${title}"
- Describes PROFESSIONAL PHOTOGRAPHY scene with real humans in natural settings
- Emphasizes DOCUMENTARY/PHOTOJOURNALISM style (NOT illustration or cartoon)
- Specifies camera type, lens, lighting conditions (professional DSLR photography)
- Describes authentic human subjects with genuine expressions and natural body language
- Includes exact color codes and composition details
- Appeals to ${targetAudience}
- Maintains ${tone} tone
- EXPLICITLY prohibits cartoon, illustration, 3D render, CGI, or animated styles
- Ends with technical photography specifications

DALL-E 3 Prompt:`;

    try {
      const result = await model.generateContent(prompt);
      const response = await result.response;
      let imagePrompt = response.text().trim();

      // Remove any markdown formatting
      imagePrompt = imagePrompt.replace(/```.*?\n|```/g, '').trim();

      // Enforce uniformity suffix - PROFESSIONAL PHOTOGRAPHY ONLY
      const uniformitySuffix = ` | Professional blog header photograph | 1792x1024 wide landscape format | Shot on Canon EOS R5, 35mm f/2.8 lens | Natural lighting, golden hour, soft shadows | ${colors} color palette | Real environment setting | Professional editorial photography | Documentary style with authentic humans | Genuine expressions, natural poses | High-resolution DSLR image quality | NO cartoon, illustration, 3D render, CGI, or animated style | NO text, logos, or direct face shots | Photojournalism aesthetic`;

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

  async generateImageNative(prompt, options = {}) {
    if (!geminiClient) {
      if (!process.env.GEMINI_API_KEY) throw new Error('Gemini not configured');
      geminiClient = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    }

    try {
      // Use Gemini 2.5 Flash Image model for native image generation
      const imageModel = geminiClient.getGenerativeModel({
        model: 'gemini-2.5-flash-image'
      });

      const result = await imageModel.generateContent(prompt);
      const response = await result.response;

      // Extract inline image data from response
      for (const part of response.candidates[0].content.parts) {
        if (part.inlineData) {
          // Return base64 image data
          return {
            base64: part.inlineData.data,
            mimeType: part.inlineData.mimeType || 'image/png'
          };
        }
      }

      throw new Error('No image data in response');
    } catch (error) {
      console.error('Gemini Image Generation Error:', error.message);
      throw error;
    }
  },

  isConfigured() {
    return !!process.env.GEMINI_API_KEY;
  },
};
