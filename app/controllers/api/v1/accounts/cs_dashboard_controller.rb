class Api::V1::Accounts::CsDashboardController < Api::V1::Accounts::BaseController
  DEFAULT_RANGE = 30.days

  before_action :check_authorization

  def show
    render json: Reports::CsDashboardService.new(
      account: Current.account,
      range_start: range_start,
      range_end: range_end,
      group_by: params[:group_by],
      timezone_offset: params[:timezone_offset],
      inbox_id: params[:inbox_id]
    ).perform
  end

  private

  def range_end
    @range_end ||= params[:until].present? ? Time.zone.at(params[:until].to_i) : Time.current
  end

  def range_start
    @range_start ||= params[:since].present? ? Time.zone.at(params[:since].to_i) : range_end - DEFAULT_RANGE
  end

  def check_authorization
    authorize :report, :view?
  end
end
