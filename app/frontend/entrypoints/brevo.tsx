import React from 'react';
import { createRoot } from 'react-dom/client';
import BrevoConfiguration from '../components/BrevoConfiguration';

// Get data from Rails
const companyElement = document.getElementById('company-data');
const flashMessagesElement = document.getElementById('flash-messages-data');
const errorElement = document.getElementById('error-data');
const debugElement = document.getElementById('debug-data');

const company = companyElement ? JSON.parse(companyElement.textContent || '{}') : undefined;
const flashMessages = flashMessagesElement ? JSON.parse(flashMessagesElement.textContent || '{}') : undefined;
const error = errorElement ? JSON.parse(errorElement.textContent || '{}').error : undefined;
const debug = debugElement ? JSON.parse(debugElement.textContent || '{}') : undefined;

// Debug logging
console.log('Company data:', company);
console.log('Debug info:', debug);
console.log('API key path:', company?.integration_setting?.credentials?.brevo?.api_key);

const root = createRoot(document.getElementById('root') as HTMLElement);
root.render(
  <BrevoConfiguration
    company={company}
    flashMessages={flashMessages}
    error={error}
  />
);
