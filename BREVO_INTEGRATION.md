# Brevo Integration

This Rails application includes a comprehensive Brevo (formerly Sendinblue) integration that provides email marketing, transactional emails, contact management, and webhook handling capabilities.

## Features

- **Transactional Emails**: Send individual or batch transactional emails
- **Contact Management**: Create, update, delete, and import contacts
- **Email Campaigns**: Create and manage marketing campaigns
- **Webhooks**: Handle Brevo webhook events for tracking
- **Lists Management**: Manage contact lists
- **Attributes Management**: Manage contact attributes

## Setup

### 1. Environment Variables

Add the following environment variables to your `.env` file:

```bash
BREVO_API_KEY=your_brevo_api_key_here
BREVO_DEFAULT_SENDER_NAME=Your App Name
BREVO_DEFAULT_SENDER_EMAIL=noreply@yourdomain.com
BREVO_WEBHOOK_SECRET=your_webhook_secret_here
```

### 2. Install Dependencies

The integration uses the existing `httparty` gem in your Gemfile. No additional gems are required.

```bash
bundle install
```

### 3. Configure Integration Settings

For each company, you can set up Brevo credentials:

```ruby
company = Company.find(1)
integration_setting = company.integration_setting
integration_setting.brevo_api_key = "your_api_key"
company.integration_setting.credentials['brevo'] = { 'api_key' => 'your_brevo_api_key' }
integration_setting.save!
```

## Usage

### Sending Transactional Emails

```ruby
# Using the helper method
result = send_brevo_email(
  company,
  [{ email: "user@example.com", name: "John Doe" }],
  "Welcome!",
  "<h1>Welcome to our platform!</h1>",
  "Welcome to our platform!"
)

# Using the service directly
result = Brevo::EmailService.call(
  api_key: company.integration_setting.brevo_api_key,
  action: 'send_transactional',
  sender_name: "Your App",
  sender_email: "noreply@yourdomain.com",
  recipients: [{ email: "user@example.com", name: "John Doe" }],
  subject: "Welcome!",
  html_content: "<h1>Welcome!</h1>",
  text_content: "Welcome!"
)
```

### Managing Contacts

```ruby
# Create a contact
result = Brevo::ContactService.call(
  api_key: company.integration_setting.brevo_api_key,
  action: 'create',
  email: "user@example.com",
  attributes: {
    'FIRSTNAME' => 'John',
    'LASTNAME' => 'Doe',
    'SMS' => '+1234567890'
  },
  list_ids: [1, 2]
)

# Update a contact
result = Brevo::ContactService.call(
  api_key: company.integration_setting.brevo_api_key,
  action: 'update',
  identifier: "user@example.com",
  attributes: {
    'FIRSTNAME' => 'Jane'
  }
)

# Get contact information
result = Brevo::ContactService.call(
  api_key: company.integration_setting.brevo_api_key,
  action: 'get',
  identifier: "user@example.com"
)
```

### Email Campaigns

```ruby
# Create a campaign
result = Brevo::CampaignService.call(
  api_key: company.integration_setting.brevo_api_key,
  action: 'create',
  name: "Monthly Newsletter",
  subject: "Newsletter - January 2024",
  sender_name: "Your Company",
  sender_email: "newsletter@yourdomain.com",
  html_content: "<h1>Monthly Newsletter</h1>",
  recipients: { listIds: [1] }
)

# Send a campaign
result = Brevo::CampaignService.call(
  api_key: company.integration_setting.brevo_api_key,
  action: 'send',
  campaign_id: campaign_id
)

# Get campaign report
result = Brevo::CampaignService.call(
  api_key: company.integration_setting.brevo_api_key,
  action: 'report',
  campaign_id: campaign_id
)
```

### Webhooks

The integration includes a webhook controller at `/brevo/webhook` that handles various Brevo events:

- **Transactional Events**: sent, delivered, opened, clicked, bounced, complained
- **Marketing Events**: opened, clicked, unsubscribed
- **Inbound Events**: email parsing

Configure webhooks in your Brevo dashboard to point to:
```
https://yourdomain.com/brevo/webhook
```

### Error Handling

All services use the `BrevoApiError` class for error handling:

```ruby
begin
  result = Brevo::EmailService.call(...)
rescue BrevoApiError => e
  Rails.logger.error "Brevo API Error: #{e.message} (Status: #{e.status_code})"
end
```

## API Reference

### BrevoClient

The main client class that handles all API communication with Brevo.

**Methods:**
- `send_transactional_email(email_params)`
- `send_batch_emails(batch_params)`
- `create_contact(contact_params)`
- `update_contact(identifier, contact_params)`
- `get_contact(identifier)`
- `delete_contact(identifier)`
- `import_contacts(import_params)`
- `create_campaign(campaign_params)`
- `get_campaign(campaign_id)`
- `update_campaign(campaign_id, campaign_params)`
- `send_campaign(campaign_id)`
- `get_campaign_report(campaign_id)`
- `create_webhook(webhook_params)`
- `get_webhooks`
- `update_webhook(webhook_id, webhook_params)`
- `delete_webhook(webhook_id)`

### Service Classes

- **Brevo::EmailService**: Handles transactional and batch emails
- **Brevo::ContactService**: Manages contacts and contact lists
- **Brevo::CampaignService**: Creates and manages email campaigns
- **Brevo::WebhookService**: Manages webhook configurations

### Helper Methods

The `BrevoHelper` module provides convenient methods for common operations:

- `send_brevo_email(company, recipients, subject, html_content, text_content, template_params)`
- `create_brevo_contact(company, email, attributes, list_ids)`
- `update_brevo_contact(company, identifier, attributes)`
- `create_brevo_campaign(company, name, subject, html_content, recipients)`
- `send_brevo_campaign(company, campaign_id)`
- `create_brevo_webhook(company, url, events)`

## Configuration

### Brevo Configuration

The integration is configured in `config/initializers/brevo.rb`:

```ruby
Rails.application.configure do
  config.brevo = ActiveSupport::OrderedOptions.new
  config.brevo.api_key = ENV['BREVO_API_KEY']
  config.brevo.default_sender = {
    name: ENV['BREVO_DEFAULT_SENDER_NAME'],
    email: ENV['BREVO_DEFAULT_SENDER_EMAIL']
  }
  config.brevo.webhook_secret = ENV['BREVO_WEBHOOK_SECRET']
  config.brevo.rate_limit = {
    requests_per_minute: 100,
    burst_limit: 10
  }
end
```

### Integration Settings

Each company can have its own Brevo configuration stored in the `integration_settings` table:

```ruby
integration_setting = company.integration_setting
integration_setting.brevo_api_key = "company_specific_api_key"
company.integration_setting.credentials['brevo'] = { 'api_key' => 'your_brevo_api_key' }
integration_setting.save!
```

## Examples

See `lib/brevo_integration_examples.rb` for comprehensive usage examples including:

- Sending welcome emails
- Creating customer contacts
- Managing email campaigns
- Setting up webhooks
- Importing contacts from CSV
- Getting campaign analytics
- Sending personalized batch emails

## Testing

The integration includes proper error handling and logging. For testing, you can:

1. Use the Brevo sandbox environment
2. Mock the HTTParty responses
3. Use VCR for recording API interactions

## Rate Limiting

The integration respects Brevo's rate limits:
- 100 requests per minute by default
- Burst limit of 10 requests
- Automatic retry with exponential backoff (can be implemented)

## Security

- API keys are stored encrypted in the database
- Webhook signatures are verified for security
- All API calls use HTTPS
- Sensitive data is not logged

## Support

For issues with the integration, check:
1. Brevo API documentation: https://developers.brevo.com/
2. Application logs for error messages
3. Brevo dashboard for API usage and limits
