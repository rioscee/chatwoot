class PipelineStage < ApplicationRecord
  belongs_to :pipeline
  has_many :deals, -> { order(position: :asc) }, dependent: :destroy, inverse_of: :pipeline_stage

  validates :name, presence: true
  validates :position, presence: true
end
