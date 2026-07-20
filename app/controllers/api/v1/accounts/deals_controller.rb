class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  before_action :set_deal, only: [:show, :update, :destroy]

  def index
    @deals = Deal.where(account_id: current_account.id).order(position: :asc)
    render json: @deals.to_json(include: :contact)
  end

  def create
    @deal = Deal.new(deal_params.merge(account_id: current_account.id))
    if @deal.save
      render json: @deal.to_json(include: :contact), status: :created
    else
      render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    old_stage_id = @deal.pipeline_stage_id
    old_position = @deal.position

    new_stage_id = params[:deal][:pipeline_stage_id]&.to_i
    new_position = params[:deal][:position]&.to_i

    if @deal.update(deal_params)
      if new_stage_id && (new_stage_id != old_stage_id || new_position != old_position)
        reorder_deals(old_stage_id, new_stage_id, @deal.id, new_position)
      end
      render json: @deal.to_json(include: :contact)
    else
      render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @deal.destroy
    head :no_content
  end

  private

  def set_deal
    @deal = Deal.where(account_id: current_account.id).find(params[:id])
  end

  def deal_params
    params.require(:deal).permit(:name, :value, :currency, :status, :pipeline_stage_id, :contact_id, :position)
  end

  def reorder_deals(old_stage_id, new_stage_id, deal_id, new_position)
    # Simple reordering logic:
    new_stage_deals = Deal.where(pipeline_stage_id: new_stage_id).where.not(id: deal_id).order(position: :asc).to_a
    new_stage_deals.insert([new_position, new_stage_deals.size].min, Deal.find(deal_id))
    new_stage_deals.each_with_index do |d, index|
      d.update_column(:position, index)
    end

    if old_stage_id != new_stage_id
      old_stage_deals = Deal.where(pipeline_stage_id: old_stage_id).order(position: :asc)
      old_stage_deals.each_with_index do |d, index|
        d.update_column(:position, index)
      end
    end
  end
end
