class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :set_pipeline, only: [:show, :update, :destroy]

  def index
    @pipelines = current_account.pipelines.includes(pipeline_stages: :deals)
    if @pipelines.empty?
      default_pipeline = current_account.pipelines.create!(name: 'Embudo de Ventas Principal')
      @pipelines = [default_pipeline]
    end

    # Fetch open conversations that do not have a deal yet
    deal_contact_ids = Deal.where(account_id: current_account.id).pluck(:contact_id).compact
    open_conversations = current_account.conversations.where(status: :open).includes(:contact)
    
    virtual_deals = open_conversations.reject { |c| deal_contact_ids.include?(c.contact_id) }.map do |conv|
      {
        id: "conv-#{conv.id}",
        name: "Conversación ##{conv.display_id} - #{conv.contact.name}",
        value: 0.0,
        currency: 'USD',
        status: 'open',
        pipeline_stage_id: @pipelines.first.pipeline_stages.first.id,
        contact_id: conv.contact_id,
        position: 0,
        is_virtual: true,
        contact: conv.contact.as_json(only: [:id, :name, :email, :phone_number])
      }
    end

    pipelines_json = @pipelines.as_json(include: { pipeline_stages: { include: { deals: { include: :contact } } } })
    
    if pipelines_json.any? && pipelines_json.first['pipeline_stages'].any?
      first_stage = pipelines_json.first['pipeline_stages'].first
      first_stage['deals'] = virtual_deals + (first_stage['deals'] || [])
    end

    render json: pipelines_json
  end

  def create
    @pipeline = current_account.pipelines.new(pipeline_params)
    if @pipeline.save
      render json: @pipeline.to_json(include: :pipeline_stages), status: :created
    else
      render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @pipeline.update(pipeline_params)
      render json: @pipeline
    else
      render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @pipeline.destroy
    head :no_content
  end

  private

  def set_pipeline
    @pipeline = current_account.pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name)
  end
end
