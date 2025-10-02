import React, { useState } from 'react';
import { RefreshCw, Plus, Users, UserCheck, UserX } from 'lucide-react';
import Modal from './Modal';

interface ListManagementTabProps {
  isConnected: boolean;
  lists: Array<{
    id: number;
    name: string;
  }>;
  segmentMappings: {
    everyone_list_id?: string;
    customer_list_id?: string;
    rep_list_id?: string;
  };
  folderInfo?: {
    id: number;
    name: string;
  };
  handleSyncLists: () => void;
  handleUpdateSegmentMapping: (segment: string, listId: string) => void;
  handleCreateList: (segment: string, listName: string) => void;
  handleSyncSegment: (segment: string) => void;
  isSyncingSegment?: string | null;
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
  folderInfo,
  handleSyncLists,
  handleUpdateSegmentMapping,
  handleCreateList,
  handleSyncSegment,
  isSyncingSegment
}) => {
  const [segmentMappings, setSegmentMappings] = useState<SegmentMapping>({
    everyoneListId: initialSegmentMappings.everyone_list_id || '',
    customerListId: initialSegmentMappings.customer_list_id || '',
    repListId: initialSegmentMappings.rep_list_id || ''
  });
  const [isLoading, setIsLoading] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newListName, setNewListName] = useState('');
  const [selectedSegment, setSelectedSegment] = useState<keyof SegmentMapping | null>(null);

  const handleListChange = (segment: keyof SegmentMapping, listId: string) => {
    setSegmentMappings(prev => ({
      ...prev,
      [segment]: listId
    }));
    
    // Convert segment key to the format expected by the backend
    const segmentKey = segment.replace('ListId', '_list_id');
    handleUpdateSegmentMapping(segmentKey, listId);
  };

  const handleCreateListClick = (segment: keyof SegmentMapping) => {
    setSelectedSegment(segment);
    setNewListName('');
    setShowCreateModal(true);
  };

  const handleCreateListSubmit = async () => {
    if (!newListName.trim() || !selectedSegment) return;
    
    setIsLoading(true);
    try {
      // Convert segment key to the format expected by the backend
      const segmentKey = selectedSegment.replace('ListId', '_list_id');
      await handleCreateList(segmentKey, newListName);
      
      // Close the modal
      setShowCreateModal(false);
      setNewListName('');
      setSelectedSegment(null);
    } catch (error) {
      console.error('Error creating list:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCloseModal = () => {
    setShowCreateModal(false);
    setNewListName('');
    setSelectedSegment(null);
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
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-2xl font-bold text-gray-900">Contact List Management</h3>
          <p className="mt-2 text-lg text-gray-600">
            Map your customer segments to Brevo contact lists
          </p>
        </div>
        <button
          onClick={handleSyncLists}
          disabled={isLoading}
          className="inline-flex items-center px-6 py-3 border border-gray-300 shadow-sm text-base font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition-colors duration-200"
        >
          <RefreshCw className={`w-5 h-5 mr-3 ${isLoading ? 'animate-spin' : ''}`} />
          Sync Lists
        </button>
      </div>

      {/* Folder Information */}
      {folderInfo && (
        <div className="mb-8 p-6 bg-blue-50 border-2 border-blue-200 rounded-xl">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
              <Users className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-blue-900">Brevo Folder</h3>
              <p className="text-blue-700">
                All lists will be created in: <span className="font-semibold">{folderInfo.name}</span>
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Segments */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {segments.map((segment) => {
          const IconComponent = segment.icon;
          const selectedList = lists.find(list => list.id.toString() === segmentMappings[segment.key]);
          
          return (
            <div key={segment.key} className={`border-2 rounded-xl p-8 ${getColorClasses(segment.color)}`}>
              <div className="flex items-start justify-between mb-6">
                <div className="flex items-start space-x-4">
                  <div className={`flex-shrink-0 ${getIconColorClasses(segment.color)}`}>
                    <IconComponent className="h-8 w-8" />
                  </div>
                  <div className="flex-1">
                    <h4 className="text-xl font-bold">{segment.title}</h4>
                    <p className="text-base opacity-75 mt-2">{segment.description}</p>
                  </div>
                </div>
              </div>

              <div className="space-y-4">
                <label htmlFor={segment.key} className="block text-base font-semibold">
                  Select List
                </label>
                <div className="flex gap-3">
                  <select
                    id={segment.key}
                    value={segmentMappings[segment.key]}
                    onChange={(e) => handleListChange(segment.key, e.target.value)}
                    className="flex-1 shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full text-base border-gray-300 rounded-lg py-3 px-4"
                  >
                    <option value="">
                      {lists.length === 0 ? 'No lists available - sync first' : 'Select a list'}
                    </option>
                    {lists.map((list) => (
                      <option key={list.id} value={list.id}>
                        {list.name}
                      </option>
                    ))}
                  </select>
                  <button
                    type="button"
                    onClick={() => handleCreateListClick(segment.key)}
                    className="inline-flex items-center px-4 py-3 border border-gray-300 shadow-sm text-base font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors duration-200"
                  >
                    <Plus className="w-5 h-5 mr-2" />
                    Create New
                  </button>
                </div>

                {selectedList && (
                  <div className="mt-6 p-6 bg-white bg-opacity-60 rounded-lg border border-white border-opacity-50">
                    <div className="flex items-center justify-between text-base mb-4">
                      <span className="font-bold text-lg">{selectedList.name}</span>
                    </div>
                    
                    {/* Sync button */}
                    <div className="flex gap-3">
                      <button
                        onClick={() => handleSyncSegment(segment.key.replace('ListId', '_list_id'))}
                        disabled={isSyncingSegment === segment.key.replace('ListId', '_list_id')}
                        className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition-colors duration-200"
                      >
                        <RefreshCw className={`w-4 h-4 mr-2 ${isSyncingSegment === segment.key.replace('ListId', '_list_id') ? 'animate-spin' : ''}`} />
                        {isSyncingSegment === segment.key.replace('ListId', '_list_id') ? 'Syncing...' : 'Sync Now'}
                      </button>
                    </div>
                  </div>
                )}
              </div>

            </div>
          );
        })}
      </div>


      {/* Summary */}
      <div className="bg-gray-50 p-6 rounded-xl border border-gray-200">
        <h4 className="text-lg font-bold text-gray-900 mb-4">Configuration Summary</h4>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {segments.map((segment) => {
            const selectedList = lists.find(list => list.id.toString() === segmentMappings[segment.key]);
            return (
              <div key={segment.key} className="bg-white p-4 rounded-lg border border-gray-200">
                <div className="text-sm font-medium text-gray-500 mb-1">{segment.title}</div>
                <div className="text-base font-semibold text-gray-900">
                  {selectedList ? selectedList.name : 'Not configured'}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Create List Modal */}
      <Modal
        isOpen={showCreateModal}
        onClose={handleCloseModal}
        title={`Create New List for ${selectedSegment ? segments.find(s => s.key === selectedSegment)?.title : ''}`}
        size="md"
      >
        <div className="space-y-4">
          <div>
            <label htmlFor="list-name" className="block text-sm font-medium text-gray-700 mb-2">
              List Name
            </label>
            <input
              id="list-name"
              type="text"
              value={newListName}
              onChange={(e) => setNewListName(e.target.value)}
              placeholder={`Enter name for ${selectedSegment ? segments.find(s => s.key === selectedSegment)?.title.toLowerCase() : ''}`}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500 text-base"
              autoFocus
            />
          </div>
          
          <div className="flex justify-end space-x-3 pt-4">
            <button
              onClick={handleCloseModal}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors duration-200"
            >
              Cancel
            </button>
            <button
              onClick={handleCreateListSubmit}
              disabled={isLoading || !newListName.trim()}
              className="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors duration-200"
            >
              {isLoading ? 'Creating...' : 'Create List'}
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default ListManagementTab;
