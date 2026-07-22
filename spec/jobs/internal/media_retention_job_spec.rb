# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Internal::MediaRetentionJob do
  subject(:job) { described_class.perform_later }

  it 'enqueues the job on scheduled_jobs queue' do
    expect { job }.to have_enqueued_job(described_class).on_queue('scheduled_jobs')
  end

  describe '#perform' do
    let(:account) { create(:account) }
    let(:conversation) { create(:conversation, account: account) }
    let(:message) { create(:message, conversation: conversation, account: account) }
    let(:attachment_old) { create(:attachment, message: message, account: account, created_at: 4.months.ago) }
    let(:attachment_recent) { create(:attachment, message: message, account: account, created_at: 1.month.ago) }

    before do
      file_old = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')
      file_recent = fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png')
      attachment_old.file.attach(file_old)
      attachment_recent.file.attach(file_recent)
    end

    context 'when MEDIA_RETENTION_MONTHS is 0 (disabled)' do
      before do
        allow(GlobalConfig).to receive(:get_value).with('MEDIA_RETENTION_MONTHS').and_return('0')
      end

      it 'does not purge any attachments' do
        described_class.new.perform

        expect(attachment_old.reload.file.attached?).to be true
        expect(attachment_recent.reload.file.attached?).to be true
      end
    end

    context 'when MEDIA_RETENTION_MONTHS is set to 3' do
      before do
        allow(GlobalConfig).to receive(:get_value).with('MEDIA_RETENTION_MONTHS').and_return('3')
      end

      it 'purges attachments older than 3 months and keeps recent ones' do
        described_class.new.perform

        expect(attachment_old.reload.file.attached?).to be false
        expect(attachment_recent.reload.file.attached?).to be true
      end
    end
  end
end
