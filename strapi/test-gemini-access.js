#!/usr/bin/env node
'use strict';

require('dotenv').config();
const { GoogleGenerativeAI } = require('@google/generative-ai');

async function testGeminiAccess() {
  console.log('Testing Gemini API Access...\n');

  if (!process.env.GEMINI_API_KEY) {
    console.error('❌ GEMINI_API_KEY not found in .env file');
    return;
  }

  console.log('✅ GEMINI_API_KEY is set\n');

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

  // Test 1: Try text generation with Gemini 2.5 Flash
  console.log('Test 1: Gemini 2.5 Flash (Text Generation)');
  try {
    const textModel = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
    const result = await textModel.generateContent('Say hello in 5 words');
    const response = await result.response;
    console.log('✅ SUCCESS - Gemini 2.5 Flash works!');
    console.log('Response:', response.text().substring(0, 50));
  } catch (error) {
    console.error('❌ FAILED:', error.message);
  }

  console.log('\n---\n');

  // Test 2: Try image generation with Gemini 2.5 Flash Image
  console.log('Test 2: Gemini 2.5 Flash Image (Image Generation)');
  try {
    const imageModel = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-image' });
    const result = await imageModel.generateContent('A red apple on a white table');
    const response = await result.response;

    // Check for image data
    let hasImage = false;
    for (const part of response.candidates[0].content.parts) {
      if (part.inlineData) {
        hasImage = true;
        console.log('✅ SUCCESS - Gemini 2.5 Flash Image works!');
        console.log('Image MIME type:', part.inlineData.mimeType);
        console.log('Image size:', part.inlineData.data.length, 'bytes');
        console.log('\n🎉 YOU HAVE ACCESS TO GEMINI IMAGE GENERATION! 🎉');
        console.log('\nYou can switch from DALL-E 3 to Gemini for better realistic photography.');
        break;
      }
    }

    if (!hasImage) {
      console.log('⚠️  Response received but no image data found');
    }
  } catch (error) {
    console.error('❌ FAILED:', error.message);

    if (error.message.includes('429') || error.message.includes('quota')) {
      console.log('\n⚠️  This usually means:');
      console.log('   - Gemini Image is NOT available on free tier');
      console.log('   - You need a paid Google AI plan');
      console.log('   - OR you hit rate limits');
    } else if (error.message.includes('404') || error.message.includes('not found')) {
      console.log('\n⚠️  Model not available to your account');
    }
  }

  console.log('\n---\n');
  console.log('Summary:');
  console.log('- Text generation (Gemini 2.5 Flash): Check above');
  console.log('- Image generation (Gemini 2.5 Flash Image): Check above');
  console.log('\nIf image generation failed, continue using DALL-E 3 (current default)');
}

testGeminiAccess().catch(console.error);
