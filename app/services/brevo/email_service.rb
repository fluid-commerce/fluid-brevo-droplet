# frozen_string_literal: true

class Brevo::EmailService
  def initialize(api_key)
    @api_key = api_key
    @brevo_client = BrevoClient.new(api_key)
  end

  def send_transactional_email(sender_name:, sender_email:, recipients:, subject:, html_content:, text_content: nil, template_params: {})
    email_params = build_transactional_email_params(
      sender_name: sender_name,
      sender_email: sender_email,
      recipients: recipients,
      subject: subject,
      html_content: html_content,
      text_content: text_content,
      template_params: template_params
    )
    
    @brevo_client.send_transactional_email(email_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to send transactional email: #{e.message}")
  end

  def send_batch_emails(sender_name:, sender_email:, recipients:, subject:, html_content:, text_content: nil, template_params: {}, batch_id: nil)
    batch_params = build_batch_email_params(
      sender_name: sender_name,
      sender_email: sender_email,
      recipients: recipients,
      subject: subject,
      html_content: html_content,
      text_content: text_content,
      template_params: template_params,
      batch_id: batch_id
    )
    
    @brevo_client.send_batch_emails(batch_params)
  rescue BrevoApiError => e
    raise BrevoApiError.new("Failed to send batch emails: #{e.message}")
  end

  private

  def build_transactional_email_params(sender_name:, sender_email:, recipients:, subject:, html_content:, text_content:, template_params:)
    {
      'sender' => {
        'name' => sender_name,
        'email' => sender_email
      },
      'to' => recipients,
      'subject' => subject,
      'htmlContent' => html_content,
      'textContent' => text_content,
      'params' => template_params || {}
    }.compact
  end

  def build_batch_email_params(sender_name:, sender_email:, recipients:, subject:, html_content:, text_content:, template_params:, batch_id:)
    {
      'sender' => {
        'name' => sender_name,
        'email' => sender_email
      },
      'to' => recipients,
      'subject' => subject,
      'htmlContent' => html_content,
      'textContent' => text_content,
      'params' => template_params || {},
      'batchId' => batch_id
    }.compact
  end
end
