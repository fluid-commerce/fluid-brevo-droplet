import React, { useState, useEffect } from 'react';
import { CheckCircle, XCircle, ExternalLink, Mail, Wifi, RefreshCw, Eye, EyeOff } from 'lucide-react';

interface BrevoConfigurationProps {
  company?: {
    name: string;
    fluid_shop: string;
    integration_setting?: {
      credentials?: {
        brevo?: {
          api_key?: string;
        };
      };
    };
    updated_at?: string;
  };
  flashMessages?: {
    notice?: string;
    alert?: string;
  };
  error?: string;
}

interface ApiResponse {
  success: boolean;
  message?: string;
  error?: string;
}

const BrevoConfiguration: React.FC<BrevoConfigurationProps> = ({
  company,
  flashMessages,
  error
}) => {
  const [apiKey, setApiKey] = useState(company?.integration_setting?.credentials?.brevo?.api_key || '');
  const [isLoading, setIsLoading] = useState(false);
  const [flashMessage, setFlashMessage] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const [showPassword, setShowPassword] = useState(false);

  useEffect(() => {
    if (flashMessages?.notice) {
      setFlashMessage({ type: 'success', message: flashMessages.notice });
    } else if (flashMessages?.alert) {
      setFlashMessage({ type: 'error', message: flashMessages.alert });
    } else if (error) {
      setFlashMessage({ type: 'error', message: error });
    }
  }, [flashMessages, error]);

  // Update API key when company data changes
  useEffect(() => {
    const newApiKey = company?.integration_setting?.credentials?.brevo?.api_key || '';
    setApiKey(newApiKey);
  }, [company]);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const formData = new FormData();
      formData.append('brevo_api_key', apiKey);

      const response = await fetch('/brevo', {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setFlashMessage({ type: 'success', message: data.message || 'Brevo API key updated successfully!' });
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Failed to update configuration' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while saving' });
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyConnection = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/brevo/verify_connection', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setFlashMessage({ type: 'success', message: data.message || 'Brevo connection verified successfully!' });
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Connection verification failed' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while verifying connection' });
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyEmail = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/brevo/verify_email', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setFlashMessage({ type: 'success', message: data.message || 'Test email sent successfully! Check your inbox.' });
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Email verification failed' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while sending test email' });
    } finally {
      setIsLoading(false);
    }
  };

  const handleManualSync = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/brevo/manual_sync', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setFlashMessage({ type: 'success', message: data.message || 'Manual sync feature will be implemented soon!' });
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Sync failed' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred during sync' });
    } finally {
      setIsLoading(false);
    }
  };

  const togglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  const isConnected = apiKey.length > 0;

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        {/* Flash Messages */}
        {flashMessage && (
          <div className={`rounded-md p-4 mb-6 ${
            flashMessage.type === 'success' ? 'bg-green-50' : 'bg-red-50'
          }`}>
            <div className="flex">
              <div className="flex-shrink-0">
                {flashMessage.type === 'success' ? (
                  <CheckCircle className="h-5 w-5 text-green-400" />
                ) : (
                  <XCircle className="h-5 w-5 text-red-400" />
                )}
              </div>
              <div className="ml-3">
                <p className={`text-sm font-medium ${
                  flashMessage.type === 'success' ? 'text-green-800' : 'text-red-800'
                }`}>
                  {flashMessage.message}
                </p>
              </div>
            </div>
          </div>
        )}

        <div className="bg-white shadow rounded-lg">
          <div className="px-4 py-5 sm:p-6">
            {/* Header */}
            <div className="flex items-center justify-between mb-6">
              <div>
                <h1 className="text-2xl font-bold text-gray-900">Brevo Integration</h1>
                <p className="mt-1 text-sm text-gray-500">
                  Configure your Brevo API settings and test the connection
                </p>
              </div>
              <div className="flex items-center">
                {isConnected ? (
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    <CheckCircle className="w-2 h-2 mr-1" />
                    Connected
                  </span>
                ) : (
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                    <XCircle className="w-2 h-2 mr-1" />
                    Not Connected
                  </span>
                )}
              </div>
            </div>

            {/* Configuration Form */}
            <form onSubmit={handleSave} className="space-y-6">
              <div>
                <label htmlFor="brevo_api_key" className="block text-sm font-medium text-gray-700">
                  Brevo API Key
                </label>
                <div className="mt-1 relative">
                  <input
                    type={showPassword ? "text" : "password"}
                    id="brevo_api_key"
                    value={apiKey}
                    onChange={(e) => setApiKey(e.target.value)}
                    placeholder="Enter your Brevo API key"
                    className="shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md pr-10"
                  />
                  <button
                    type="button"
                    onClick={togglePasswordVisibility}
                    className="absolute inset-y-0 right-0 pr-3 flex items-center"
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4 text-gray-400 hover:text-gray-600" />
                    ) : (
                      <Eye className="h-4 w-4 text-gray-400 hover:text-gray-600" />
                    )}
                  </button>
                </div>
                <p className="mt-2 text-sm text-gray-500">
                  You can find your API key in your{' '}
                  <a
                    href="https://app.brevo.com/settings/keys/api"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-600 hover:text-blue-500 inline-flex items-center"
                  >
                    Brevo account settings
                    <ExternalLink className="w-3 h-3 ml-1" />
                  </a>
                </p>
              </div>


              <div className="flex justify-end">
                <button
                  type="submit"
                  disabled={isLoading}
                  className="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
                >
                  {isLoading ? 'Saving...' : 'Save Configuration'}
                </button>
              </div>
            </form>

            {/* Test & Verify Section */}
            <div className="mt-8 border-t border-gray-200 pt-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Test & Verify</h3>
                
                <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                  {/* Verify Connection Button */}
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-2">Test Connection</h4>
                    <p className="text-xs text-gray-500 mb-3">
                      Verify your API key and get account information
                    </p>
                    <button
                      onClick={handleVerifyConnection}
                      disabled={isLoading || !isConnected}
                      className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50"
                    >
                      <Wifi className="w-4 h-4 mr-1" />
                      Verify Connection
                    </button>
                  </div>

                  {/* Verify Email Button */}
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-2">Test Email</h4>
                    <p className="text-xs text-gray-500 mb-3">
                      Send a test email to verify email functionality
                    </p>
                    <button
                      onClick={handleVerifyEmail}
                      disabled={isLoading || !isConnected}
                      className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
                    >
                      <Mail className="w-4 h-4 mr-1" />
                      Send Test Email
                    </button>
                  </div>

                  {/* Manual Sync Button */}
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="text-sm font-medium text-gray-900 mb-2">Manual Sync</h4>
                    <p className="text-xs text-gray-500 mb-3">
                      Import contacts from Fluid to Brevo
                    </p>
                    <button
                      onClick={handleManualSync}
                      disabled={isLoading || !isConnected}
                      className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 disabled:opacity-50"
                    >
                      <RefreshCw className="w-4 h-4 mr-1" />
                      Sync Contacts
                    </button>
                  </div>
                </div>
              </div>

            {/* Account Information */}
            {isConnected && company && (
              <div className="mt-8 border-t border-gray-200 pt-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">Account Information</h3>
                <div className="bg-gray-50 p-4 rounded-lg">
                  <dl className="grid grid-cols-1 gap-x-4 gap-y-3 sm:grid-cols-2">
                    <div>
                      <dt className="text-sm font-medium text-gray-500">Company</dt>
                      <dd className="mt-1 text-sm text-gray-900">{company.name}</dd>
                    </div>
                    <div>
                      <dt className="text-sm font-medium text-gray-500">Fluid Shop</dt>
                      <dd className="mt-1 text-sm text-gray-900">{company.fluid_shop}</dd>
                    </div>
                    <div>
                      <dt className="text-sm font-medium text-gray-500">Integration Status</dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          Active
                        </span>
                      </dd>
                    </div>
                    <div>
                      <dt className="text-sm font-medium text-gray-500">Last Updated</dt>
                      <dd className="mt-1 text-sm text-gray-900">
                        {company?.updated_at ? 
                          new Date(company.updated_at).toLocaleString() : 
                          'Never'
                        }
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>
            )}

            {/* Help Section */}
            <div className="mt-8 border-t border-gray-200 pt-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Need Help?</h3>
              <div className="prose prose-sm text-gray-500 max-w-none">
                <ul className="list-disc pl-5 space-y-1">
                  <li>
                    Get your API key from the{' '}
                    <a
                      href="https://app.brevo.com/settings/keys/api"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:text-blue-500"
                    >
                      Brevo API settings page
                    </a>
                  </li>
                  <li>Make sure your sender email is verified in your Brevo account</li>
                  <li>
                    Check the{' '}
                    <a
                      href="https://developers.brevo.com/"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:text-blue-500"
                    >
                      Brevo API documentation
                    </a>{' '}
                    for more details
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default BrevoConfiguration;
