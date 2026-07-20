class Deal < ApplicationRecord
  belongs_to :pipeline_stage
  belongs_to :account
  belongs_to :contact, optional: true

  validates :name, presence: true
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: %w[open won lost] }

  before_validation :set_default_status, on: :create
  before_create :set_position

  private

  def set_default_status
    self.status ||= 'open'
    self.currency ||= 'USD'
  end

  def set_position
    max_position = Deal.where(pipeline_stage_id: pipeline_stage_id).maximum(:position) || -1
    self.position = max_position + 1
  end
end
