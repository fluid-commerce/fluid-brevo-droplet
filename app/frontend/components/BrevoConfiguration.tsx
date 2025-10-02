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
  lists?: Array<{
    id: number;
    name: string;
  }>;
  segment_mappings?: {
    everyone_list_id?: string;
    customer_list_id?: string;
    rep_list_id?: string;
  };
  folder_info?: {
    id: number;
    name: string;
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
  lists: initialLists,
  segment_mappings: initialSegmentMappings,
  folder_info,
  flashMessages,
  error
}) => {
  const [apiKey, setApiKey] = useState(company?.integration_setting?.credentials?.brevo?.api_key || '');
  const [isLoading, setIsLoading] = useState(false);
  const [flashMessage, setFlashMessage] = useState<{ type: 'success' | 'error'; message: string } | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const [lists, setLists] = useState(initialLists || []);
  const [segmentMappings, setSegmentMappings] = useState(initialSegmentMappings || {});
  const [activeTab, setActiveTab] = useState<'configuration' | 'list-management'>('configuration');
  const [isSyncingSegment, setIsSyncingSegment] = useState<string | null>(null);
    const [importProgress, setImportProgress] = useState<{
      percentage: number;
      message: string;
      status: 'running' | 'completed' | 'failed';
    } | null>(null);

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
        // Start polling for progress
        if (data.job_id) {
          setImportProgress({
            percentage: 0,
            message: 'Importing contacts...',
            status: 'running'
          });
          startProgressPolling(data.job_id);
        } else {
          setFlashMessage({ type: 'success', message: data.message || `Successfully synced ${segment.replace('_', ' ')} customers!` });
        }
      } else {
        setFlashMessage({ type: 'error', message: data.error || 'Failed to sync customers' });
        setIsSyncingSegment(null);
      }
    } catch (error) {
      setFlashMessage({ type: 'error', message: 'An error occurred while syncing customers' });
      setIsSyncingSegment(null);
    }
  };

  const startProgressPolling = (jobId: string) => {
    const pollInterval = setInterval(async () => {
      try {
        const response = await fetch(`/brevo/import_progress?job_id=${jobId}`, {
          headers: {
            'Accept': 'application/json',
          },
        });

        const data = await response.json();
        
        if (response.ok && data.success) {
          const progress = data.progress;
          setImportProgress({
            percentage: progress.percentage,
            message: progress.message,
            status: progress.status
          });

          if (progress.status === 'completed' || progress.status === 'failed') {
            clearInterval(pollInterval);
            setIsSyncingSegment(null);
            
            if (progress.status === 'completed') {
              setFlashMessage({ type: 'success', message: progress.message });
            } else {
              setFlashMessage({ type: 'error', message: progress.message });
            }
            
            // Clear progress after 5 seconds
            setTimeout(() => {
              setImportProgress(null);
            }, 5000);
          }
        } else {
          // Job not found or error - assume completed
          clearInterval(pollInterval);
          setIsSyncingSegment(null);
          setImportProgress({
            percentage: 100,
            message: 'Import completed',
            status: 'completed'
          });
          setFlashMessage({ type: 'success', message: 'Import completed successfully' });
          
          // Clear progress after 5 seconds
          setTimeout(() => {
            setImportProgress(null);
          }, 5000);
        }
      } catch (error) {
        console.error('Error polling progress:', error);
        clearInterval(pollInterval);
        setIsSyncingSegment(null);
        setImportProgress(null);
      }
    }, 2000); // Poll every 2 seconds
  };

  const isConnected = apiKey.length > 0;

  return (
    <div className="min-h-screen bg-gray-50 py-6 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
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

        {/* Import Progress */}
        {importProgress && (
          <div className="rounded-md p-4 mb-6 bg-blue-50 border border-blue-200">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="w-5 h-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
              </div>
              <div className="ml-3 flex-1">
                <div className="flex items-center justify-between">
                  <p className="text-sm font-medium text-blue-800">
                    {importProgress.message}
                  </p>
                  <span className="text-sm text-blue-600 font-medium">
                    {importProgress.percentage}%
                  </span>
                </div>
                <div className="mt-2">
                  <div className="w-full bg-blue-200 rounded-full h-2">
                    <div 
                      className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                      style={{ width: `${importProgress.percentage}%` }}
                    ></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        <div className="bg-white shadow-lg rounded-xl">
          <div className="px-6 py-8">
            {/* Header */}
            <div className="flex items-center justify-between mb-8">
              <div>
                <h1 className="text-3xl font-bold text-gray-900">Brevo Integration</h1>
                <p className="mt-2 text-lg text-gray-600">
                  Configure your Brevo API settings and manage customer lists
                </p>
              </div>
              <div className="flex items-center">
                {isConnected ? (
                  <span className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-green-100 text-green-800">
                    <CheckCircle className="w-4 h-4 mr-2" />
                    Connected
                  </span>
                ) : (
                  <span className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-red-100 text-red-800">
                    <XCircle className="w-4 h-4 mr-2" />
                    Not Connected
                  </span>
                )}
              </div>
            </div>

            {/* Tab Navigation */}
            <div className="border-b border-gray-200 mb-8">
              <nav className="-mb-px flex space-x-12">
                <button
                  onClick={() => setActiveTab('configuration')}
                  className={`py-4 px-2 border-b-2 font-semibold text-base transition-colors duration-200 ${
                    activeTab === 'configuration'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Configuration
                </button>
                    <button
                  onClick={() => setActiveTab('list-management')}
                  className={`py-4 px-2 border-b-2 font-semibold text-base transition-colors duration-200 ${
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
            folderInfo={folder_info}
            handleSyncLists={handleSyncLists}
            handleUpdateSegmentMapping={handleUpdateSegmentMapping}
            handleCreateList={handleCreateList}
            handleSyncSegment={handleSyncSegment}
            isSyncingSegment={isSyncingSegment}
          />
        )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default BrevoConfiguration;
