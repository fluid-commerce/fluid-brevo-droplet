import React from 'react';
import { Mail, XCircle, RefreshCw } from 'lucide-react';

interface CustomerSyncTabProps {
  isConnected: boolean;
  isLoadingCustomers: boolean;
  customerPreview: Array<{
    id: number;
    name: string;
    email: string;
    phone: string;
    created_at: string;
  }>;
  handlePreviewCustomers: () => void;
}

const CustomerSyncTab: React.FC<CustomerSyncTabProps> = ({
  isConnected,
  isLoadingCustomers,
  customerPreview,
  handlePreviewCustomers
}) => {
  return (
    <div className="space-y-6">
      <div className="bg-blue-50 border border-blue-200 rounded-md p-4">
        <div className="flex">
          <div className="flex-shrink-0">
            <Mail className="h-5 w-5 text-blue-400" />
          </div>
          <div className="ml-3">
            <h3 className="text-sm font-medium text-blue-800">
              Customer Sync
            </h3>
            <div className="mt-2 text-sm text-blue-700">
              <p>
                Import your Fluid customers to Brevo. This will sync customer data including names, emails, and contact information.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-lg font-medium text-gray-900">Customer Preview</h3>
            <p className="text-sm text-gray-500">
              Preview customers that will be synced to Brevo
            </p>
          </div>
          <button
            onClick={handlePreviewCustomers}
            disabled={isLoadingCustomers || !isConnected}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${isLoadingCustomers ? 'animate-spin' : ''}`} />
            {isLoadingCustomers ? 'Loading...' : 'Preview Customers'}
          </button>
        </div>

        {!isConnected && (
          <div className="bg-yellow-50 border border-yellow-200 rounded-md p-4">
            <div className="flex">
              <div className="flex-shrink-0">
                <XCircle className="h-5 w-5 text-yellow-400" />
              </div>
              <div className="ml-3">
                <h3 className="text-sm font-medium text-yellow-800">
                  Configuration Required
                </h3>
                <div className="mt-2 text-sm text-yellow-700">
                  <p>
                    Please configure your Brevo API key in the Configuration tab before syncing customers.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {customerPreview.length > 0 && (
          <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
            <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
              <h4 className="text-sm font-medium text-gray-900">
                Customer Preview ({customerPreview.length} customers)
              </h4>
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Name
                    </th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Email
                    </th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Phone
                    </th>
                    <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Created
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {customerPreview.map((customer) => (
                    <tr key={customer.id}>
                      <td className="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                        {customer.name}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                        {customer.email}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                        {customer.phone}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                        {customer.created_at}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {isConnected && customerPreview.length === 0 && !isLoadingCustomers && (
          <div className="text-center py-8">
            <Mail className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No customers previewed</h3>
            <p className="mt-1 text-sm text-gray-500">
              Click "Preview Customers" to see which customers will be synced.
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default CustomerSyncTab;
