class Pipeline < ApplicationRecord
  belongs_to :account
  has_many :pipeline_stages, -> { order(position: :asc) }, dependent: :destroy, inverse_of: :pipeline
  has_many :deals, through: :pipeline_stages

  validates :name, presence: true

  after_create :create_default_stages

  private

  def create_default_stages
    return if pipeline_stages.any?

    default_stages = [
      'Prospecto',
      'Contacto Realizado',
      'Demostración Programada',
      'Propuesta Enviada',
      'Negociación Iniciada'
    ]

    default_stages.each_with_index do |stage_name, index|
      pipeline_stages.create!(name: stage_name, position: index)
    end
  end
end
