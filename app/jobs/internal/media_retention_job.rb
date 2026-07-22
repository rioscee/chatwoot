# frozen_string_literal: true

class Internal::MediaRetentionJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    retention_months = (GlobalConfig.get_value('MEDIA_RETENTION_MONTHS') || '0').to_i
    return if retention_months.zero?

    cutoff_date = retention_months.months.ago

    Attachment.where('created_at < ?', cutoff_date).find_each do |attachment|
      attachment.file.purge_later if attachment.file.attached?
    end
  end
end
