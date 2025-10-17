class ActivityLog < ApplicationRecord
  belongs_to :company

  # Job types
  JOB_TYPES = %w[customer_import product_import order_import category_import attribute_creation].freeze

  # Status types
  STATUSES = %w[success error warning info].freeze

  validates :job_type, inclusion: { in: JOB_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :message, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_job_type, ->(job_type) { where(job_type: job_type) }
  scope :by_status, ->(status) { where(status: status) }

  def self.log_success(company, job_type, message, details = {})
    create!(
      company: company,
      job_type: job_type,
      status: 'success',
      message: message,
      details: details
    )
  end

  def self.log_error(company, job_type, message, details = {})
    create!(
      company: company,
      job_type: job_type,
      status: 'error',
      message: message,
      details: details
    )
  end

  def self.log_warning(company, job_type, message, details = {})
    create!(
      company: company,
      job_type: job_type,
      status: 'warning',
      message: message,
      details: details
    )
  end

  def self.log_info(company, job_type, message, details = {})
    create!(
      company: company,
      job_type: job_type,
      status: 'info',
      message: message,
      details: details
    )
  end
end
