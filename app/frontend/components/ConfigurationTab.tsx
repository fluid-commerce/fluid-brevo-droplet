import React from 'react';
import { CheckCircle, XCircle, ExternalLink, Wifi, RefreshCw, Eye, EyeOff } from 'lucide-react';

interface ConfigurationTabProps {
  apiKey: string;
  setApiKey: (key: string) => void;
  showPassword: boolean;
  togglePasswordVisibility: () => void;
  isLoading: boolean;
  isConnected: boolean;
  lists: Array<{
    id: number;
    name: string;
    totalBlacklisted?: number;
    totalSubscribers?: number;
  }>;
  defaultListId: string | number;
  handleSave: (e: React.FormEvent) => void;
  handleVerifyConnection: () => void;
  handleSyncLists: () => void;
  handleUpdateDefaultList: (listId: string) => void;
}

const ConfigurationTab: React.FC<ConfigurationTabProps> = ({
  apiKey,
  setApiKey,
  showPassword,
  togglePasswordVisibility,
  isLoading,
  isConnected,
  lists,
  defaultListId,
  handleSave,
  handleVerifyConnection,
  handleSyncLists,
  handleUpdateDefaultList
}) => {
  return (
    <div className="space-y-6">
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

        {/* Verify Connection Button */}
        {isConnected && (
          <div className="mt-4">
            <button
              type="button"
              onClick={handleVerifyConnection}
              disabled={isLoading}
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50"
            >
              <Wifi className="w-4 h-4 mr-2" />
              {isLoading ? 'Verifying...' : 'Verify Connection'}
            </button>
          </div>
        )}

        {/* Lists Configuration Section */}
        {isConnected && (
          <div className="mt-8 border-t border-gray-200 pt-6">
            <h3 className="text-lg font-medium text-gray-900 mb-4">List Management</h3>
            
            <div className="space-y-4">
              <div>
                <label htmlFor="default_list" className="block text-sm font-medium text-gray-700 mb-2">
                  Default Contact List
                </label>
                <div className="flex gap-3">
                  <select
                    id="default_list"
                    value={defaultListId}
                    onChange={(e) => handleUpdateDefaultList(e.target.value)}
                    disabled={isLoading || lists.length === 0}
                    className="flex-1 shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md disabled:opacity-50"
                  >
                    <option value="">
                      {lists.length === 0 ? 'No lists available - sync first' : 'Select a default list'}
                    </option>
                    {lists.map((list) => (
                      <option key={list.id} value={list.id}>
                        {list.name} ({list.totalSubscribers || 0} subscribers)
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    onClick={handleSyncLists}
                    disabled={isLoading}
                    className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
                  >
                    <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
                    Sync Lists
                  </button>
                </div>
                <p className="mt-2 text-sm text-gray-500">
                  Choose the default list where new contacts will be added. Use "Sync Lists" to refresh the list from Brevo.
                </p>
              </div>

              {lists.length > 0 && (
                <div className="bg-gray-50 p-4 rounded-lg">
                  <h4 className="text-sm font-medium text-gray-900 mb-2">Available Lists ({lists.length})</h4>
                  <div className="space-y-2">
                    {lists.map((list) => (
                      <div key={list.id} className="flex items-center justify-between text-sm">
                        <span className="text-gray-900">{list.name}</span>
                        <div className="flex items-center space-x-4 text-gray-500">
                          <span>{list.totalSubscribers || 0} subscribers</span>
                          {defaultListId === list.id.toString() && (
                            <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              Default
                            </span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

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
  );
};

export default ConfigurationTab;
