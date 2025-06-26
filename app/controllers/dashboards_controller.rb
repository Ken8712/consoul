class DashboardsController < ApplicationController
  def index
    @light_definitions = LightDefinition.order(:id)
  end
end
