import React, { useState } from 'react';
import { RefreshCw, Plus, Users, UserCheck, UserX } from 'lucide-react';

interface ListManagementTabProps {
  isConnected: boolean;
  lists: Array<{
    id: number;
    name: string;
    totalBlacklisted?: number;
    totalSubscribers?: number;
  }>;
  segmentMappings: {
    everyone_list_id?: string;
    customer_list_id?: string;
    rep_list_id?: string;
  };
  handleSyncLists: () => void;
  handleUpdateSegmentMapping: (segment: string, listId: string) => void;
  handleCreateList: (segment: string, listName: string) => void;
  handleSyncSegment: (segment: string) => void;
  handlePreviewSegment: (segment: string) => void;
  isSyncingSegment?: string | null;
  isPreviewingSegment?: string | null;
  segmentPreview?: any[];
}

interface SegmentMapping {
  everyoneListId: string;
  customerListId: string;
  repListId: string;
}

const ListManagementTab: React.FC<ListManagementTabProps> = ({
  isConnected,
  lists,
  segmentMappings: initialSegmentMappings,
  handleSyncLists,
  handleUpdateSegmentMapping,
  handleCreateList,
  handleSyncSegment,
  handlePreviewSegment,
  isSyncingSegment,
  isPreviewingSegment,
  segmentPreview = []
}) => {
  const [segmentMappings, setSegmentMappings] = useState<SegmentMapping>({
    everyoneListId: initialSegmentMappings.everyone_list_id || '',
    customerListId: initialSegmentMappings.customer_list_id || '',
    repListId: initialSegmentMappings.rep_list_id || ''
  });
  const [isLoading, setIsLoading] = useState(false);
  const [showCreateForm, setShowCreateForm] = useState<string | null>(null);
  const [newListName, setNewListName] = useState('');

  const handleListChange = (segment: keyof SegmentMapping, listId: string) => {
    setSegmentMappings(prev => ({
      ...prev,
      [segment]: listId
    }));
    
    // Convert segment key to the format expected by the backend
    const segmentKey = segment.replace('ListId', '_list_id');
    handleUpdateSegmentMapping(segmentKey, listId);
  };

  const handleCreateListSubmit = async (segment: keyof SegmentMapping) => {
    if (!newListName.trim()) return;
    
    setIsLoading(true);
    try {
      // Convert segment key to the format expected by the backend
      const segmentKey = segment.replace('ListId', '_list_id');
      await handleCreateList(segmentKey, newListName);
      
      // Close the form
      setShowCreateForm(null);
      setNewListName('');
    } catch (error) {
      console.error('Error creating list:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const segments = [
    {
      key: 'everyoneListId' as keyof SegmentMapping,
      title: 'Everyone List',
      description: 'All customers from your Fluid store',
      icon: Users,
      color: 'blue'
    },
    {
      key: 'customerListId' as keyof SegmentMapping,
      title: 'Customer List',
      description: 'Non-rep customers only',
      icon: UserCheck,
      color: 'green'
    },
    {
      key: 'repListId' as keyof SegmentMapping,
      title: 'Rep List',
      description: 'Rep customers only',
      icon: UserX,
      color: 'purple'
    }
  ];

  const getColorClasses = (color: string) => {
    const colors = {
      blue: 'bg-blue-50 border-blue-200 text-blue-700',
      green: 'bg-green-50 border-green-200 text-green-700',
      purple: 'bg-purple-50 border-purple-200 text-purple-700'
    };
    return colors[color as keyof typeof colors] || colors.blue;
  };

  const getIconColorClasses = (color: string) => {
    const colors = {
      blue: 'text-blue-600',
      green: 'text-green-600',
      purple: 'text-purple-600'
    };
    return colors[color as keyof typeof colors] || colors.blue;
  };

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <div className="mx-auto h-12 w-12 text-gray-400">
          <Users className="h-12 w-12" />
        </div>
        <h3 className="mt-2 text-sm font-medium text-gray-900">Not Connected</h3>
        <p className="mt-1 text-sm text-gray-500">
          Please configure your Brevo API key first to manage contact lists.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-medium text-gray-900">Contact List Management</h3>
          <p className="text-sm text-gray-500">
            Map your customer segments to Brevo contact lists
          </p>
        </div>
        <button
          onClick={handleSyncLists}
          disabled={isLoading}
          className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
        >
          <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
          Sync Lists
        </button>
      </div>

      {/* Segments */}
      <div className="space-y-6">
        {segments.map((segment) => {
          const IconComponent = segment.icon;
          const selectedList = lists.find(list => list.id.toString() === segmentMappings[segment.key]);
          
          return (
            <div key={segment.key} className={`border rounded-lg p-6 ${getColorClasses(segment.color)}`}>
              <div className="flex items-start justify-between">
                <div className="flex items-start space-x-3">
                  <div className={`flex-shrink-0 ${getIconColorClasses(segment.color)}`}>
                    <IconComponent className="h-6 w-6" />
                  </div>
                  <div className="flex-1">
                    <h4 className="text-lg font-medium">{segment.title}</h4>
                    <p className="text-sm opacity-75 mt-1">{segment.description}</p>
                  </div>
                </div>
              </div>

              <div className="mt-4">
                <label htmlFor={segment.key} className="block text-sm font-medium mb-2">
                  Select List
                </label>
                <div className="flex gap-3">
                  <select
                    id={segment.key}
                    value={segmentMappings[segment.key]}
                    onChange={(e) => handleListChange(segment.key, e.target.value)}
                    className="flex-1 shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  >
                    <option value="">
                      {lists.length === 0 ? 'No lists available - sync first' : 'Select a list'}
                    </option>
                    {lists.map((list) => (
                      <option key={list.id} value={list.id}>
                        {list.name} ({list.totalSubscribers || 0} subscribers)
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    onClick={() => setShowCreateForm(segment.key)}
                    className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    <Plus className="w-4 h-4 mr-2" />
                    Create New
                  </button>
                </div>

                {selectedList && (
                  <div className="mt-3 p-3 bg-white bg-opacity-50 rounded-md">
                    <div className="flex items-center justify-between text-sm mb-3">
                      <span className="font-medium">{selectedList.name}</span>
                      <div className="flex items-center space-x-4 text-gray-500">
                        <span>{selectedList.totalSubscribers || 0} subscribers</span>
                        <span>{selectedList.totalBlacklisted || 0} blacklisted</span>
                      </div>
                    </div>
                    
                    {/* Sync and Preview buttons */}
                    <div className="flex gap-2">
                      <button
                        onClick={() => handlePreviewSegment(segment.key.replace('ListId', '_list_id'))}
                        disabled={isPreviewingSegment === segment.key.replace('ListId', '_list_id')}
                        className="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
                      >
                        <RefreshCw className={`w-3 h-3 mr-1 ${isPreviewingSegment === segment.key.replace('ListId', '_list_id') ? 'animate-spin' : ''}`} />
                        {isPreviewingSegment === segment.key.replace('ListId', '_list_id') ? 'Loading...' : 'Preview'}
                      </button>
                      <button
                        onClick={() => handleSyncSegment(segment.key.replace('ListId', '_list_id'))}
                        disabled={isSyncingSegment === segment.key.replace('ListId', '_list_id')}
                        className="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
                      >
                        <RefreshCw className={`w-3 h-3 mr-1 ${isSyncingSegment === segment.key.replace('ListId', '_list_id') ? 'animate-spin' : ''}`} />
                        {isSyncingSegment === segment.key.replace('ListId', '_list_id') ? 'Syncing...' : 'Sync Now'}
                      </button>
                    </div>
                  </div>
                )}
              </div>

              {/* Create List Form */}
              {showCreateForm === segment.key && (
                <div className="mt-4 p-4 bg-white bg-opacity-50 rounded-md">
                  <div className="flex gap-3">
                    <input
                      type="text"
                      value={newListName}
                      onChange={(e) => setNewListName(e.target.value)}
                      placeholder={`Enter name for ${segment.title.toLowerCase()}`}
                      className="flex-1 shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md"
                    />
                    <button
                      onClick={() => handleCreateListSubmit(segment.key)}
                      disabled={isLoading || !newListName.trim()}
                      className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
                    >
                      {isLoading ? 'Creating...' : 'Create'}
                    </button>
                    <button
                      onClick={() => {
                        setShowCreateForm(null);
                        setNewListName('');
                      }}
                      className="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Customer Preview */}
      {segmentPreview.length > 0 && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h4 className="text-sm font-medium text-blue-900 mb-3">Customer Preview ({segmentPreview.length} customers)</h4>
          <div className="max-h-64 overflow-y-auto">
            <div className="space-y-2">
              {segmentPreview.slice(0, 10).map((customer, index) => (
                <div key={index} className="flex items-center justify-between text-sm bg-white p-2 rounded">
                  <div className="flex items-center space-x-3">
                    <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                      <span className="text-xs font-medium text-blue-600">
                        {customer.name?.charAt(0) || '?'}
                      </span>
                    </div>
                    <div>
                      <div className="font-medium text-gray-900">{customer.name || 'Unknown'}</div>
                      <div className="text-gray-500">{customer.email}</div>
                    </div>
                  </div>
                  <div className="text-gray-500 text-xs">
                    {customer.phone && `📞 ${customer.phone}`}
                  </div>
                </div>
              ))}
              {segmentPreview.length > 10 && (
                <div className="text-center text-sm text-gray-500 py-2">
                  ... and {segmentPreview.length - 10} more customers
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Summary */}
      <div className="bg-gray-50 p-4 rounded-lg">
        <h4 className="text-sm font-medium text-gray-900 mb-2">Configuration Summary</h4>
        <div className="space-y-1 text-sm text-gray-600">
          {segments.map((segment) => {
            const selectedList = lists.find(list => list.id.toString() === segmentMappings[segment.key]);
            return (
              <div key={segment.key} className="flex justify-between">
                <span>{segment.title}:</span>
                <span className="font-medium">
                  {selectedList ? selectedList.name : 'Not configured'}
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default ListManagementTab;
