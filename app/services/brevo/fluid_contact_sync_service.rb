# frozen_string_literal: true

class Brevo::FluidContactSyncService
  def initialize(api_key)
    @api_key = api_key
    @brevo_client = BrevoClient.new(api_key)
  end

  def sync_customers(customers:, list_id: nil)
    return { success: false, error: "No customers provided" } if customers.empty?
    return { success: false, error: "No list ID provided" } if list_id.nil?

    # Transform Fluid customers to Brevo format
    brevo_contacts = customers.map do |customer|
      {
        email: customer.email,
        attributes: {
          'FIRSTNAME' => customer.first_name,
          'LASTNAME' => customer.last_name,
          'SMS' => customer.phone,
          'COMPANY' => customer.company_name,
          'CUSTOMER_TYPE' => customer.customer_type,
          'RANK' => customer.rank,
          'SPONSOR_ID' => customer.sponsor_id,
          'SPONSOR_NAME' => customer.sponsor_name,
          'JOIN_DATE' => customer.created_at&.strftime('%Y-%m-%d'),
          'FLUID_SHOP' => customer.fluid_shop
        }.compact
      }
    end

    # Batch create/update contacts
    result = @brevo_client.create_contacts_batch({
      contacts: brevo_contacts,
      listIds: [list_id],
      updateExistingContacts: true
    })

    { success: true, result: result, synced_count: brevo_contacts.length }
  rescue BrevoApiError => e
    { success: false, error: "Failed to sync customers: #{e.message}" }
  end

  def sync_contacts(contacts:, list_id: nil)
    return { success: false, error: "No contacts provided" } if contacts.empty?
    return { success: false, error: "No list ID provided" } if list_id.nil?

    # Transform contacts to Brevo format
    brevo_contacts = contacts.map do |contact|
      {
        email: contact.email,
        attributes: {
          'FIRSTNAME' => contact.first_name,
          'LASTNAME' => contact.last_name,
          'SMS' => contact.phone,
          'COMPANY' => contact.company_name,
          'CONTACT_TYPE' => contact.contact_type,
          'SOURCE' => contact.source,
          'FLUID_SHOP' => contact.fluid_shop
        }.compact
      }
    end

    result = @brevo_client.create_contacts_batch({
      contacts: brevo_contacts,
      listIds: [list_id],
      updateExistingContacts: true
    })

    { success: true, result: result, synced_count: brevo_contacts.length }
  rescue BrevoApiError => e
    { success: false, error: "Failed to sync contacts: #{e.message}" }
  end

  def setup_mlm_attributes
    mlm_attributes = [
      {
        name: 'CUSTOMER_TYPE',
        type: 'text',
        enumeration: ['customer', 'prospect', 'rep', 'admin']
      },
      {
        name: 'RANK',
        type: 'text',
        enumeration: ['bronze', 'silver', 'gold', 'platinum', 'diamond']
      },
      {
        name: 'SPONSOR_ID',
        type: 'text'
      },
      {
        name: 'SPONSOR_NAME',
        type: 'text'
      },
      {
        name: 'JOIN_DATE',
        type: 'date'
      },
      {
        name: 'FLUID_SHOP',
        type: 'text'
      },
      {
        name: 'CONTACT_TYPE',
        type: 'text',
        enumeration: ['customer', 'prospect', 'rep', 'lead']
      },
      {
        name: 'SOURCE',
        type: 'text',
        enumeration: ['website', 'referral', 'social', 'email', 'other']
      }
    ]

    created_attributes = []
    
    mlm_attributes.each do |attr|
      begin
        result = @brevo_client.create_attribute(attr)
        created_attributes << result
      rescue BrevoApiError => e
        # Attribute might already exist, log and continue
        Rails.logger.warn "Attribute #{attr[:name]} might already exist: #{e.message}"
      end
    end

    { success: true, created_attributes: created_attributes, created_count: created_attributes.length }
  rescue => e
    { success: false, error: "Failed to setup MLM attributes: #{e.message}" }
  end

  def create_fluid_lists
    lists = [
      {
        name: 'Fluid Customers',
        folderId: 1
      },
      {
        name: 'Fluid Prospects',
        folderId: 1
      },
      {
        name: 'Fluid Reps',
        folderId: 1
      },
      {
        name: 'Fluid Leads',
        folderId: 1
      }
    ]

    created_lists = []
    
    lists.each do |list|
      begin
        result = @brevo_client.create_list(list)
        created_lists << result
      rescue BrevoApiError => e
        # List might already exist, try to find it
        existing_lists = @brevo_client.get_lists
        existing_list = existing_lists['lists'].find { |l| l['name'] == list[:name] }
        created_lists << existing_list if existing_list
      end
    end

    { success: true, created_lists: created_lists, created_count: created_lists.length }
  rescue => e
    { success: false, error: "Failed to create Fluid lists: #{e.message}" }
  end

  def test_connection
    # Test API key validity and get account info
    account_info = @brevo_client.get_account
    account_limits = @brevo_client.get_account_limits
    
    {
      success: true,
      valid: true,
      account: account_info,
      limits: account_limits
    }
  rescue BrevoApiError => e
    {
      success: false,
      valid: false,
      error: e.message,
      status_code: e.status_code
    }
  rescue => e
    { success: false, error: "Connection test failed: #{e.message}" }
  end

  private

  def sync_customers
    customers = context.customers || []
    list_id = context.list_id || context.default_list_id
    
    return context.fail!(message: "No customers provided") if customers.empty?
    return context.fail!(message: "No list ID provided") if list_id.nil?

    # Transform Fluid customers to Brevo format
    brevo_contacts = customers.map do |customer|
      {
        email: customer.email,
        attributes: {
          'FIRSTNAME' => customer.first_name,
          'LASTNAME' => customer.last_name,
          'SMS' => customer.phone,
          'COMPANY' => customer.company_name,
          'CUSTOMER_TYPE' => customer.customer_type,
          'RANK' => customer.rank,
          'SPONSOR_ID' => customer.sponsor_id,
          'SPONSOR_NAME' => customer.sponsor_name,
          'JOIN_DATE' => customer.created_at&.strftime('%Y-%m-%d'),
          'FLUID_SHOP' => customer.fluid_shop
        }.compact
      }
    end

    # Batch create/update contacts
    result = context.brevo_client.create_contacts_batch({
      contacts: brevo_contacts,
      listIds: [list_id],
      updateExistingContacts: true
    })

    context.sync_result = result
    context.synced_count = brevo_contacts.length
  rescue BrevoApiError => e
    context.fail!(message: "Failed to sync customers: #{e.message}")
  end

  def sync_contacts
    contacts = context.contacts || []
    list_id = context.list_id || context.default_list_id
    
    return context.fail!(message: "No contacts provided") if contacts.empty?
    return context.fail!(message: "No list ID provided") if list_id.nil?

    # Transform contacts to Brevo format
    brevo_contacts = contacts.map do |contact|
      {
        email: contact.email,
        attributes: {
          'FIRSTNAME' => contact.first_name,
          'LASTNAME' => contact.last_name,
          'SMS' => contact.phone,
          'COMPANY' => contact.company_name,
          'CONTACT_TYPE' => contact.contact_type,
          'SOURCE' => contact.source,
          'FLUID_SHOP' => contact.fluid_shop
        }.compact
      }
    end

    result = context.brevo_client.create_contacts_batch({
      contacts: brevo_contacts,
      listIds: [list_id],
      updateExistingContacts: true
    })

    context.sync_result = result
    context.synced_count = brevo_contacts.length
  rescue BrevoApiError => e
    context.fail!(message: "Failed to sync contacts: #{e.message}")
  end

  def setup_mlm_attributes
    mlm_attributes = [
      {
        name: 'CUSTOMER_TYPE',
        type: 'text',
        enumeration: ['customer', 'prospect', 'rep', 'admin']
      },
      {
        name: 'RANK',
        type: 'text',
        enumeration: ['bronze', 'silver', 'gold', 'platinum', 'diamond']
      },
      {
        name: 'SPONSOR_ID',
        type: 'text'
      },
      {
        name: 'SPONSOR_NAME',
        type: 'text'
      },
      {
        name: 'JOIN_DATE',
        type: 'date'
      },
      {
        name: 'FLUID_SHOP',
        type: 'text'
      },
      {
        name: 'CONTACT_TYPE',
        type: 'text',
        enumeration: ['customer', 'prospect', 'rep', 'lead']
      },
      {
        name: 'SOURCE',
        type: 'text',
        enumeration: ['website', 'referral', 'social', 'email', 'other']
      }
    ]

    created_attributes = []
    
    mlm_attributes.each do |attr|
      begin
        result = context.brevo_client.create_attribute(attr)
        created_attributes << result
      rescue BrevoApiError => e
        # Attribute might already exist, log and continue
        Rails.logger.warn "Attribute #{attr[:name]} might already exist: #{e.message}"
      end
    end

    context.attributes_result = created_attributes
    context.created_count = created_attributes.length
  rescue => e
    context.fail!(message: "Failed to setup MLM attributes: #{e.message}")
  end

  def create_fluid_lists
    lists = [
      {
        name: 'Fluid Customers',
        folderId: 1
      },
      {
        name: 'Fluid Prospects',
        folderId: 1
      },
      {
        name: 'Fluid Reps',
        folderId: 1
      },
      {
        name: 'Fluid Leads',
        folderId: 1
      }
    ]

    created_lists = []
    
    lists.each do |list|
      begin
        result = context.brevo_client.create_list(list)
        created_lists << result
      rescue BrevoApiError => e
        # List might already exist, try to find it
        existing_lists = context.brevo_client.get_lists
        existing_list = existing_lists['lists'].find { |l| l['name'] == list[:name] }
        created_lists << existing_list if existing_list
      end
    end

    context.lists_result = created_lists
    context.created_count = created_lists.length
  rescue => e
    context.fail!(message: "Failed to create Fluid lists: #{e.message}")
  end

  def test_connection
    # Test API key validity and get account info
    account_info = context.brevo_client.get_account
    account_limits = context.brevo_client.get_account_limits
    
    context.connection_result = {
      valid: true,
      account: account_info,
      limits: account_limits
    }
  rescue BrevoApiError => e
    context.connection_result = {
      valid: false,
      error: e.message,
      status_code: e.status_code
    }
  rescue => e
    context.fail!(message: "Connection test failed: #{e.message}")
  end
end
