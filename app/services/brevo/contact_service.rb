# frozen_string_literal: true

class Brevo::ContactService
  def initialize(api_key)
    @api_key = api_key
    @brevo_client = BrevoClient.new(api_key)
  end

  def create_contact(email:, attributes: {}, list_ids: [], update_enabled: false, email_blacklisted: false, sms_blacklisted: false, unlink_list_ids: [])
    contact_params = build_contact_params(
      email: email,
      attributes: attributes,
      list_ids: list_ids,
      update_enabled: update_enabled,
      email_blacklisted: email_blacklisted,
      sms_blacklisted: sms_blacklisted,
      unlink_list_ids: unlink_list_ids
    )
    
    @brevo_client.create_contact(contact_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to create contact: #{e.message}")
  end

  def update_contact(identifier:, attributes: {}, list_ids: [], update_enabled: false, email_blacklisted: false, sms_blacklisted: false, unlink_list_ids: [])
    contact_params = build_contact_params(
      email: identifier,
      attributes: attributes,
      list_ids: list_ids,
      update_enabled: update_enabled,
      email_blacklisted: email_blacklisted,
      sms_blacklisted: sms_blacklisted,
      unlink_list_ids: unlink_list_ids
    )
    
    @brevo_client.update_contact(identifier, contact_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to update contact: #{e.message}")
  end

  def get_contact(identifier)
    @brevo_client.get_contact(identifier)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to get contact: #{e.message}")
  end

  def delete_contact(identifier)
    @brevo_client.delete_contact(identifier)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to delete contact: #{e.message}")
  end

  def import_contacts(file_body:, list_ids: [], notify_url: nil, new_list: {}, email_blacklist: false, sms_blacklist: false, update_existing_contacts: true, empty_contacts_attributes: false)
    import_params = build_import_params(
      file_body: file_body,
      list_ids: list_ids,
      notify_url: notify_url,
      new_list: new_list,
      email_blacklist: email_blacklist,
      sms_blacklist: sms_blacklist,
      update_existing_contacts: update_existing_contacts,
      empty_contacts_attributes: empty_contacts_attributes
    )
    
    @brevo_client.import_contacts(import_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to import contacts: #{e.message}")
  end

  private

  def build_contact_params(email:, attributes:, list_ids:, update_enabled:, email_blacklisted:, sms_blacklisted:, unlink_list_ids:)
    {
      'email' => email,
      'attributes' => attributes || {},
      'listIds' => list_ids || [],
      'updateEnabled' => update_enabled || false,
      'emailBlacklisted' => email_blacklisted || false,
      'smsBlacklisted' => sms_blacklisted || false,
      'unlinkListIds' => unlink_list_ids || []
    }.compact
  end

  def build_import_params(file_body:, list_ids:, notify_url:, new_list:, email_blacklist:, sms_blacklist:, update_existing_contacts:, empty_contacts_attributes:)
    {
      'fileBody' => file_body,
      'listIds' => list_ids || [],
      'notifyUrl' => notify_url,
      'newList' => new_list || {},
      'emailBlacklist' => email_blacklist || false,
      'smsBlacklist' => sms_blacklist || false,
      'updateExistingContacts' => update_existing_contacts || true,
      'emptyContactsAttributes' => empty_contacts_attributes || false
    }.compact
  end
end
