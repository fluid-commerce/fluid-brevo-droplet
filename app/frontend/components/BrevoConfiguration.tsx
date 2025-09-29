import React, { useState, useEffect } from 'react';
import { CheckCircle, XCircle } from 'lucide-react';
import ConfigurationTab from './ConfigurationTab';
import ListManagementTab from './ListManagementTab';

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
      settings?: {
        lists?: Array<{
          id: number;
          name: string;
          totalBlacklisted?: number;
          totalSubscribers?: number;
        }>;
        segment_mappings?: {
          everyone_list_id?: string;
          customer_list_id?: string;
          rep_list_id?: string;
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
  const [lists, setLists] = useState(company?.integration_setting?.settings?.lists || []);
  const [segmentMappings, setSegmentMappings] = useState(company?.integration_setting?.settings?.segment_mappings || {});
  const [activeTab, setActiveTab] = useState<'configuration' | 'list-management'>('configuration');
  const [isSyncingSegment, setIsSyncingSegment] = useState<string | null>(null);
  const [isPreviewingSegment, setIsPreviewingSegment] = useState<string | null>(null);
  const [segmentPreview, setSegmentPreview] = useState<any[]>([]);

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
      // First save the current API key
      const formData = new FormData();
      formData.append('brevo_api_key', apiKey);
      
      const saveResponse = await fetch('/brevo', {
        method: 'PATCH',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const saveData = await saveResponse.json();
      
      if (!saveResponse.ok || !saveData.success) {
        setFlashMessage({ type: 'error', message: saveData.error || 'Failed to save API key before verification' });
        return;
      }

      // Then verify the connection
      const verifyResponse = await fetch('/brevo/verify_connection', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const verifyData = await verifyResponse.json();
      
      if (verifyResponse.ok && verifyData.success) {
        setFlashMessage({ type: 'success', message: verifyData.message || 'Brevo connection verified successfully!' });
      } else {
        setFlashMessage({ type: 'error', message: verifyData.error || 'Connection verification failed' });
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

  const handleSyncLists = async () => {
    setIsLoading(true);
    try {
      const response = await fetch('/brevo/sync_lists', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setLists(data.lists || []);
        setFlashMessage({ type: 'success', message: data.message || 'Lists synced successfully!' });
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Failed to sync lists' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while syncing lists' });
    } finally {
      setIsLoading(false);
    }
  };



  const handleUpdateSegmentMapping = async (segment: string, listId: string) => {
    try {
      const response = await fetch('/brevo/update_segment_mapping', {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ segment, list_id: listId }),
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setSegmentMappings(prev => ({
          ...prev,
          [segment]: listId
        }));
        setFlashMessage({ type: 'success', message: data.message || 'Segment mapping updated successfully!' });
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Failed to update segment mapping' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while updating segment mapping' });
    }
  };

  const handleCreateList = async (segment: string, listName: string) => {
    try {
      const response = await fetch('/brevo/create_list', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ segment, list_name: listName }),
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setFlashMessage({ type: 'success', message: data.message || 'List created successfully!' });
        // Refresh lists to include the new one
        handleSyncLists();
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Failed to create list' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while creating list' });
    }
  };

  const handlePreviewSegment = async (segment: string) => {
    setIsPreviewingSegment(segment);
    try {
      const response = await fetch(`/brevo/preview_segment?segment=${segment}`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
        },
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setSegmentPreview(data.customers || []);
        setFlashMessage({ type: 'success', message: `Found ${data.count || 0} customers for ${segment.replace('_', ' ')}` });
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Failed to preview customers' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while previewing customers' });
    } finally {
      setIsPreviewingSegment(null);
    }
  };

  const handleSyncSegment = async (segment: string) => {
    setIsSyncingSegment(segment);
    try {
      const response = await fetch('/brevo/sync_segment', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ segment }),
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        setFlashMessage({ type: 'success', message: data.message || `Successfully synced ${segment.replace('_', ' ')} customers!` });
        // Clear the preview after successful sync
        setSegmentPreview([]);
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Failed to sync customers' });
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while syncing customers' });
    } finally {
      setIsSyncingSegment(null);
    }
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
                  Configure your Brevo API settings and sync customers
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

            {/* Tab Navigation */}
            <div className="border-b border-gray-200 mb-6">
              <nav className="-mb-px flex space-x-8">
                <button
                  onClick={() => setActiveTab('configuration')}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'configuration'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Configuration
                </button>
                <button
                  onClick={() => setActiveTab('list-management')}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'list-management'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Contact List Management
                </button>
              </nav>
            </div>

            {/* Tab Content */}
            {activeTab === 'configuration' && (
              <ConfigurationTab
                apiKey={apiKey}
                setApiKey={setApiKey}
                showPassword={showPassword}
                togglePasswordVisibility={togglePasswordVisibility}
                isLoading={isLoading}
                isConnected={isConnected}
                handleSave={handleSave}
                handleVerifyConnection={handleVerifyConnection}
              />
            )}

            {activeTab === 'list-management' && (
              <ListManagementTab
                isConnected={isConnected}
                lists={lists}
                segmentMappings={segmentMappings}
                handleSyncLists={handleSyncLists}
                handleUpdateSegmentMapping={handleUpdateSegmentMapping}
                handleCreateList={handleCreateList}
                handleSyncSegment={handleSyncSegment}
                handlePreviewSegment={handlePreviewSegment}
                isSyncingSegment={isSyncingSegment}
                isPreviewingSegment={isPreviewingSegment}
                segmentPreview={segmentPreview}
              />
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default BrevoConfiguration;
