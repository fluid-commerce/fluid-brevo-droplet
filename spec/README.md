# RSpec Test Suite with VCR

This test suite uses VCR (Video Cassette Recorder) to record and replay HTTP interactions with external APIs (Brevo and Fluid). This allows you to run tests without needing actual API credentials after the initial recording.

## Setup

### 1. Install Dependencies

Make sure all gems are installed:

```bash
bundle install
```

### 2. Environment Variables

Create a `.env.test` file in the root directory with your real API credentials for the initial cassette recording:

```bash
# .env.test
BREVO_API_KEY=your_real_brevo_api_key
FLUID_AUTH_TOKEN=your_real_fluid_auth_token
```

**Important:** Add `.env.test` to your `.gitignore` to prevent committing sensitive credentials.

## Recording VCR Cassettes

### First Time Setup - Recording Real Responses

When you run the tests for the first time with real credentials, VCR will record the HTTP interactions and save them as "cassettes" in `spec/fixtures/vcr_cassettes/`.

```bash
# Run all specs and record cassettes
bundle exec rspec

# Run specific spec file and record its cassettes
bundle exec rspec spec/services/brevo_client_spec.rb

# Run specific test and record its cassette
bundle exec rspec spec/services/brevo_client_spec.rb:10
```

### What Gets Recorded?

VCR records:
- Request method (GET, POST, PUT, DELETE)
- Request URL
- Request body
- Response status
- Response headers
- Response body

### What Gets Filtered?

Sensitive data is automatically filtered in the cassettes:
- Brevo API keys are replaced with `<BREVO_API_KEY>`
- Fluid auth tokens are replaced with `<FLUID_AUTH_TOKEN>`

This means you can safely commit the cassette files to version control.

## Running Tests Without Real Credentials

Once cassettes are recorded, anyone can run the tests without real API credentials:

```bash
# Run all tests using recorded cassettes
bundle exec rspec

# Tests will use the recorded HTTP interactions from cassettes
# No actual API calls will be made
```

## Re-recording Cassettes

If the API responses change or you need to update the cassettes:

### Option 1: Delete and Re-record All Cassettes

```bash
# Delete all existing cassettes
rm -rf spec/fixtures/vcr_cassettes/*

# Re-run tests with real credentials to record new cassettes
BREVO_API_KEY=your_key FLUID_AUTH_TOKEN=your_token bundle exec rspec
```

### Option 2: Delete and Re-record Specific Cassettes

```bash
# Delete a specific cassette
rm spec/fixtures/vcr_cassettes/brevo_client_get_account.json

# Re-run the specific test to record new cassette
BREVO_API_KEY=your_key bundle exec rspec spec/services/brevo_client_spec.rb:15
```

### Option 3: Force Re-record with VCR Option

Edit the VCR configuration in `spec/support/vcr.rb` to use `:all` record mode:

```ruby
config.default_cassette_options = {
  record: :all,  # Change from :once to :all
  # ...
}
```

Then run your tests and change it back to `:once`.

## Test Structure

### Services Tests
- `spec/services/brevo_client_spec.rb` - Tests for Brevo API client

### Jobs Tests
- `spec/jobs/order_import_job_spec.rb` - Tests for order import from Fluid to Brevo
- `spec/jobs/product_import_job_spec.rb` - Tests for product import
- `spec/jobs/customer_import_job_spec.rb` - Tests for customer import
- `spec/jobs/category_import_job_spec.rb` - Tests for category import

### Controller Tests
- `spec/controllers/brevo_configuration_controller_spec.rb` - Tests for Brevo configuration controller

### Factories
- `spec/factories/companies.rb` - Factory for Company model
- `spec/factories/integration_settings.rb` - Factory for IntegrationSetting model

## VCR Configuration

The VCR configuration is in `spec/support/vcr.rb`:

- **Cassette Library**: `spec/fixtures/vcr_cassettes/`
- **Hook Into**: WebMock (intercepts HTTP requests)
- **Record Mode**: `:once` (only record if cassette doesn't exist)
- **Match Requests On**: Method, URI, and Body
- **Serialize With**: JSON format

## Using VCR in Tests

### Automatic VCR Usage

Tests tagged with `:vcr` will automatically use VCR:

```ruby
it 'imports products from Fluid', :vcr do
  # This test will use VCR automatically
  result = ProductImportJob.new.perform(company.id)
  expect(result).to be_success
end
```

### Manual VCR Usage

You can also manually control VCR cassettes:

```ruby
it 'makes API call' do
  VCR.use_cassette('my_custom_cassette') do
    # Code that makes HTTP requests
    response = client.get_account
    expect(response).to be_present
  end
end
```

## Troubleshooting

### "Real HTTP connections are disabled"

This error occurs when:
1. No cassette exists for the test
2. The request doesn't match any recorded interaction

**Solution**: Record the cassette with real credentials:

```bash
BREVO_API_KEY=your_key FLUID_AUTH_TOKEN=your_token bundle exec rspec
```

### "Cassette contains X unused HTTP interactions"

This warning occurs when recorded interactions aren't used in the test.

**Solution**: This is usually harmless but you can clean up cassettes:

1. Delete the cassette file
2. Re-record with the current test code

### API Responses Changed

If the API changes and tests start failing:

1. Delete the affected cassettes
2. Re-record with real credentials
3. Update tests if needed

## Best Practices

1. **Commit Cassettes**: Always commit cassette files to version control so others can run tests without credentials
2. **Review Cassettes**: Review cassette files before committing to ensure no sensitive data leaked
3. **Keep Fresh**: Re-record cassettes periodically (e.g., monthly) to ensure they stay current with API changes
4. **Descriptive Names**: Use descriptive test names as they become cassette filenames
5. **Minimal Requests**: Keep tests focused to minimize the number of HTTP requests per test

## Running Tests in CI/CD

In CI/CD pipelines, the cassettes should be committed to version control, so:

```yaml
# Example GitHub Actions workflow
- name: Run RSpec
  run: bundle exec rspec
  # No API credentials needed - cassettes are used
```

## Generating Coverage Reports

To generate test coverage reports:

```bash
# Add simplecov to your Gemfile if not already present
bundle add simplecov --group test

# Run tests with coverage
COVERAGE=true bundle exec rspec
```

## Additional Resources

- [VCR Documentation](https://github.com/vcr/vcr)
- [WebMock Documentation](https://github.com/bblimke/webmock)
- [RSpec Documentation](https://rspec.info/)
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot)

