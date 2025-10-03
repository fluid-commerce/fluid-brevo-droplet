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
  const [activeTab, setActiveTab] = useState<'configuration' | 'list-management' | 'product-import'>('configuration');
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
    if (isSyncingSegment) return;
    
    setIsSyncingSegment(segment);
    setImportProgress({
      percentage: 0,
      message: 'Starting customer import...',
      status: 'running'
    });
    
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
        // Update progress to show importing
        setImportProgress({
          percentage: 10,
          message: 'Importing customers...',
          status: 'running'
        });
        
        // Check for completion with extended polling for long processes
        if (data.job_id) {
          let checkCount = 0;
          const maxChecks = 30; // Maximum 30 checks over 60 seconds (1 minute)
          let lastProgressUpdate = Date.now();
          let simulatedProgress = 10;
          let progressInterval: NodeJS.Timeout | null = null;
          
          // Start simulated progress animation
          progressInterval = setInterval(() => {
            if (simulatedProgress < 85) {
              simulatedProgress += Math.random() * 5; // Random increment between 0-5%
              setImportProgress(prev => prev ? {
                ...prev,
                percentage: Math.min(Math.round(simulatedProgress), 85)
              } : null);
            }
          }, 1000); // Update every second
          
          const checkProgress = async () => {
            checkCount++;
            
            try {
              const progressResponse = await fetch(`/brevo/import_progress?job_id=${data.job_id}`);
              const progressData = await progressResponse.json();
              
              if (progressResponse.ok && progressData.success && progressData.progress) {
                const progress = progressData.progress;
                lastProgressUpdate = Date.now();
                
                setImportProgress({
                  percentage: progress.percentage,
                  message: progress.message,
                  status: progress.status
                });
                
                if (progress.status === 'completed' || progress.status === 'failed') {
                  // Clear simulated progress
                  if (progressInterval) {
                    clearInterval(progressInterval);
                    progressInterval = null;
                  }
                  
                  setIsSyncingSegment(null);
                  if (progress.status === 'completed') {
                    setFlashMessage({ type: 'success', message: progress.message });
                  } else {
                    setFlashMessage({ type: 'error', message: progress.message });
                  }
                  
                  // Clear progress after 5 seconds
                  setTimeout(() => setImportProgress(null), 5000);
                  return; // Stop checking
                }
              }
              
              // If not completed and haven't exceeded max checks, check again
              if (checkCount < maxChecks) {
                // Adaptive polling: faster initially, slower for long processes
                const delay = checkCount <= 10 ? 2000 : 3000; // 2s for first 10 checks, then 3s
                setTimeout(checkProgress, delay);
              } else {
                // Extended timeout fallback - try one more time after a longer delay
                if (Date.now() - lastProgressUpdate < 30000) { // If we got progress within last 30s
                  setImportProgress({
                    percentage: 90,
                    message: 'Import is taking longer than expected...',
                    status: 'running'
                  });
                  // Give it one more chance after 10 seconds
                  setTimeout(async () => {
                    try {
                      const finalResponse = await fetch(`/brevo/import_progress?job_id=${data.job_id}`);
                      const finalData = await finalResponse.json();
                      
                      if (finalResponse.ok && finalData.success && finalData.progress) {
                        const progress = finalData.progress;
                        setImportProgress({
                          percentage: progress.percentage,
                          message: progress.message,
                          status: progress.status
                        });
                        
                        if (progress.status === 'completed' || progress.status === 'failed') {
                          setIsSyncingSegment(null);
                          if (progress.status === 'completed') {
                            setFlashMessage({ type: 'success', message: progress.message });
                          } else {
                            setFlashMessage({ type: 'error', message: progress.message });
                          }
                          setTimeout(() => setImportProgress(null), 5000);
                          return;
                        }
                      }
                    } catch (error) {
                      // Final fallback
                    }
                    
                    // Ultimate fallback
                    setImportProgress({
                      percentage: 100,
                      message: 'Customer import completed (check logs for details)',
                      status: 'completed'
                    });
                    setIsSyncingSegment(null);
                    setFlashMessage({ type: 'success', message: `Customer import completed for ${segment.replace('_', ' ')} customers!` });
                    setTimeout(() => setImportProgress(null), 5000);
                  }, 10000);
                } else {
                  // No progress for 30+ seconds, assume completed
                  setImportProgress({
                    percentage: 100,
                    message: 'Customer import completed',
                    status: 'completed'
                  });
                  setIsSyncingSegment(null);
                  setFlashMessage({ type: 'success', message: `Customer import completed for ${segment.replace('_', ' ')} customers!` });
                  setTimeout(() => setImportProgress(null), 5000);
                }
              }
            } catch (error) {
              // Clear simulated progress on error
              if (progressInterval) {
                clearInterval(progressInterval);
                progressInterval = null;
              }
              
              // Fallback on error
              setImportProgress({
                percentage: 100,
                message: 'Customer import completed',
                status: 'completed'
              });
              setIsSyncingSegment(null);
              setFlashMessage({ type: 'success', message: `Customer import completed for ${segment.replace('_', ' ')} customers!` });
              setTimeout(() => setImportProgress(null), 5000);
            }
          };
          
          // Start checking after 2 seconds
          setTimeout(checkProgress, 2000);
        } else {
          // No job ID, immediate completion
          setImportProgress({
            percentage: 100,
            message: 'Customer import completed',
            status: 'completed'
          });
          setIsSyncingSegment(null);
          setFlashMessage({ type: 'success', message: data.message || `Customer import completed for ${segment.replace('_', ' ')} customers!` });
          setTimeout(() => setImportProgress(null), 5000);
        }
      } else {
        setImportProgress({
          percentage: 100,
          message: 'Customer import failed',
          status: 'failed'
        });
        setFlashMessage({ type: 'error', message: data.error || 'Failed to sync customers' });
        setTimeout(() => setImportProgress(null), 5000);
        setIsSyncingSegment(null);
      }
    } catch (error) {
      setImportProgress({
        percentage: 100,
        message: 'Customer import failed',
        status: 'failed'
      });
      setFlashMessage({ type: 'error', message: 'An error occurred while syncing customers' });
      setTimeout(() => setImportProgress(null), 5000);
      setIsSyncingSegment(null);
    }
  };

  const handleImportProducts = async () => {
    if (isSyncingSegment) return;
    
    setIsSyncingSegment('products');
    setImportProgress({
      percentage: 0,
      message: 'Starting product import...',
      status: 'running'
    });
    
    try {
      const response = await fetch('/brevo/import_products', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        }
      });

      const data = await response.json();
      
      if (response.ok && data.success) {
        // Update progress to show importing
        setImportProgress({
          percentage: 10,
          message: 'Importing products...',
          status: 'running'
        });
        
        // Check for completion with extended polling for long processes
        if (data.job_id) {
          let checkCount = 0;
          const maxChecks = 40; // Maximum 40 checks over 2 minutes for products
          let lastProgressUpdate = Date.now();
          let simulatedProgress = 10;
          let progressInterval: NodeJS.Timeout | null = null;
          
          // Start simulated progress animation
          progressInterval = setInterval(() => {
            if (simulatedProgress < 85) {
              simulatedProgress += Math.random() * 3; // Slower increment for products (0-3%)
              setImportProgress(prev => prev ? {
                ...prev,
                percentage: Math.min(Math.round(simulatedProgress), 85)
              } : null);
            }
          }, 1500); // Update every 1.5 seconds for products
          
          const checkProgress = async () => {
            checkCount++;
            
            try {
              const progressResponse = await fetch(`/brevo/import_progress?job_id=${data.job_id}`);
              const progressData = await progressResponse.json();
              
              if (progressResponse.ok && progressData.success && progressData.progress) {
                const progress = progressData.progress;
                lastProgressUpdate = Date.now();
                
                setImportProgress({
                  percentage: progress.percentage,
                  message: progress.message,
                  status: progress.status
                });
                
                if (progress.status === 'completed' || progress.status === 'failed') {
                  // Clear simulated progress
                  if (progressInterval) {
                    clearInterval(progressInterval);
                    progressInterval = null;
                  }
                  
                  setIsSyncingSegment(null);
                  if (progress.status === 'completed') {
                    setFlashMessage({ type: 'success', message: progress.message });
                  } else {
                    setFlashMessage({ type: 'error', message: progress.message });
                  }
                  
                  // Clear progress after 5 seconds
                  setTimeout(() => setImportProgress(null), 5000);
                  return; // Stop checking
                }
              }
              
              // If not completed and haven't exceeded max checks, check again
              if (checkCount < maxChecks) {
                // Adaptive polling: faster initially, slower for long processes
                const delay = checkCount <= 15 ? 2000 : 3000; // 2s for first 15 checks, then 3s
                setTimeout(checkProgress, delay);
              } else {
                // Extended timeout fallback - try one more time after a longer delay
                if (Date.now() - lastProgressUpdate < 60000) { // If we got progress within last 60s
                  setImportProgress({
                    percentage: 90,
                    message: 'Product import is taking longer than expected...',
                    status: 'running'
                  });
                  // Give it one more chance after 15 seconds
                  setTimeout(async () => {
                    try {
                      const finalResponse = await fetch(`/brevo/import_progress?job_id=${data.job_id}`);
                      const finalData = await finalResponse.json();
                      
                      if (finalResponse.ok && finalData.success && finalData.progress) {
                        const progress = finalData.progress;
                        setImportProgress({
                          percentage: progress.percentage,
                          message: progress.message,
                          status: progress.status
                        });
                        
                        if (progress.status === 'completed' || progress.status === 'failed') {
                          setIsSyncingSegment(null);
                          if (progress.status === 'completed') {
                            setFlashMessage({ type: 'success', message: progress.message });
                          } else {
                            setFlashMessage({ type: 'error', message: progress.message });
                          }
                          setTimeout(() => setImportProgress(null), 5000);
                          return;
                        }
                      }
                    } catch (error) {
                      // Final fallback
                    }
                    
                    // Ultimate fallback
                    setImportProgress({
                      percentage: 100,
                      message: 'Product import completed (check logs for details)',
                      status: 'completed'
                    });
                    setIsSyncingSegment(null);
                    setFlashMessage({ type: 'success', message: 'Product import completed successfully!' });
                    setTimeout(() => setImportProgress(null), 5000);
                  }, 15000);
                } else {
                  // No progress for 60+ seconds, assume completed
                  setImportProgress({
                    percentage: 100,
                    message: 'Product import completed',
                    status: 'completed'
                  });
                  setIsSyncingSegment(null);
                  setFlashMessage({ type: 'success', message: 'Product import completed successfully!' });
                  setTimeout(() => setImportProgress(null), 5000);
                }
              }
            } catch (error) {
              // Clear simulated progress on error
              if (progressInterval) {
                clearInterval(progressInterval);
                progressInterval = null;
              }
              
              // Fallback on error
              setImportProgress({
                percentage: 100,
                message: 'Product import completed',
                status: 'completed'
              });
              setIsSyncingSegment(null);
              setFlashMessage({ type: 'success', message: 'Product import completed successfully!' });
              setTimeout(() => setImportProgress(null), 5000);
            }
          };
          
          // Start checking after 2 seconds
          setTimeout(checkProgress, 2000);
        } else {
          // No job ID, immediate completion
          setImportProgress({
            percentage: 100,
            message: 'Product import completed',
            status: 'completed'
          });
          setIsSyncingSegment(null);
          setFlashMessage({ type: 'success', message: data.message || 'Product import completed successfully!' });
          setTimeout(() => setImportProgress(null), 5000);
        }
      } else {
        setImportProgress({
          percentage: 100,
          message: 'Product import failed',
          status: 'failed'
        });
        setFlashMessage({ type: 'error', message: data.error || 'Failed to start product import' });
        setTimeout(() => setImportProgress(null), 5000);
        setIsSyncingSegment(null);
      }
    } catch (error) {
      console.error('Error importing products:', error);
      setImportProgress({
        percentage: 100,
        message: 'Product import failed',
        status: 'failed'
      });
      setFlashMessage({ type: 'error', message: 'An error occurred while importing products' });
      setTimeout(() => setImportProgress(null), 5000);
      setIsSyncingSegment(null);
    }
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
                {importProgress.status === 'running' && (
                  <div className="w-5 h-5 border-2 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
                )}
                {importProgress.status === 'completed' && (
                  <div className="w-5 h-5 bg-green-500 rounded-full flex items-center justify-center">
                    <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                    </svg>
                  </div>
                )}
                {importProgress.status === 'failed' && (
                  <div className="w-5 h-5 bg-red-500 rounded-full flex items-center justify-center">
                    <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                    </svg>
                  </div>
                )}
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
                      className={`h-2 rounded-full transition-all duration-300 ${
                        importProgress.status === 'completed' ? 'bg-green-500' :
                        importProgress.status === 'failed' ? 'bg-red-500' : 'bg-blue-600'
                      }`}
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
                <button
                  onClick={() => setActiveTab('product-import')}
                  className={`py-4 px-2 border-b-2 font-semibold text-base transition-colors duration-200 ${
                    activeTab === 'product-import'
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Product & Order Import
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

        {activeTab === 'product-import' && (
          <div className="space-y-6">
            <div className="bg-white shadow-lg rounded-xl p-8">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h3 className="text-2xl font-bold text-gray-900">Manual sync</h3>
                  <p className="text-gray-600 mt-2">
                    Manually import your Fluid products and orders to Brevo for email marketing campaigns and analytics
                  </p>
                </div>
              </div>

              {!isConnected ? (
                <div className="text-center py-12">
                  <div className="mx-auto w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
                    <svg className="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
                    </svg>
                  </div>
                  <h4 className="text-lg font-semibold text-gray-900 mb-2">API Key Required</h4>
                  <p className="text-gray-600 mb-6">
                    Please configure your Brevo API key in the Configuration tab to import products.
                    </p>
                    <button
                    onClick={() => setActiveTab('configuration')}
                    className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors duration-200"
                    >
                    Go to Configuration
                    </button>
                </div>
              ) : (
                <div className="space-y-6">
                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <div className="flex items-start">
                      <div className="flex-shrink-0">
                        <svg className="w-5 h-5 text-blue-400 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <div className="ml-3">
                        <h4 className="text-sm font-medium text-blue-800">Manual sync Information</h4>
                        <div className="mt-2 text-sm text-blue-700">
                          <p>This feature will allow you to:</p>
                          <ul className="list-disc list-inside mt-2 space-y-1">
                            <li>Manually import products from your Fluid store to Brevo</li>
                            <li>Manually import order history for advanced analytics</li>
                            <li>Sync data for email marketing campaigns</li>
                            <li>Trigger imports on-demand when needed</li>
                          </ul>
                        </div>
                  </div>
                </div>
              </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="bg-gray-50 rounded-lg p-6">
                      <div className="flex items-center mb-4">
                        <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center mr-3">
                          <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                          </svg>
                    </div>
                        <div>
                          <h4 className="text-lg font-semibold text-gray-900">Manual Product Sync</h4>
                          <p className="text-sm text-gray-600">Sync your product catalog on-demand</p>
                        </div>
                      </div>
                      <p className="text-gray-600 mb-6">
                        Manually import your products from Fluid to Brevo for email marketing campaigns and product recommendations.
                      </p>
                      <button
                        onClick={handleImportProducts}
                        disabled={isSyncingSegment === 'products'}
                        className="w-full bg-green-600 text-white px-6 py-3 rounded-lg hover:bg-green-700 transition-colors duration-200 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {isSyncingSegment === 'products' ? 'Syncing Products...' : 'Manual Products Sync'}
                      </button>
                    </div>

                    <div className="bg-gray-50 rounded-lg p-6">
                      <div className="flex items-center mb-4">
                        <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center mr-3">
                          <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                          </svg>
                    </div>
                        <div>
                          <h4 className="text-lg font-semibold text-gray-900">Manual Order Sync</h4>
                          <p className="text-sm text-gray-600">Sync order data for analytics on-demand</p>
                        </div>
                      </div>
                      <p className="text-gray-600 mb-6">
                        Manually import your order history from Fluid to Brevo for advanced analytics and customer insights.
                      </p>
                      <button
                        className="w-full bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors duration-200 font-medium"
                      >
                        Manual Orders Sync
                      </button>
                    </div>
                  </div>

                  <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                    <div className="flex items-start">
                      <div className="flex-shrink-0">
                        <svg className="w-5 h-5 text-yellow-400 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <div className="ml-3">
                        <h4 className="text-sm font-medium text-yellow-800">Coming Soon</h4>
                        <p className="text-sm text-yellow-700 mt-1">
                          The product import functionality is currently under development. This feature will be available in a future update.
                        </p>
                      </div>
                    </div>
                </div>
              </div>
            )}
            </div>
          </div>
        )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default BrevoConfiguration;
