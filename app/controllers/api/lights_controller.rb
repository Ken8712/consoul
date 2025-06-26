class Api::LightsController < ApplicationController
  before_action :authenticate_user!

  def increment
    light_key = params[:light_key]
    
    if light_key.present?
      current_user.increment_light(light_key)
      render json: { success: true, message: 'Lightが増加しました' }
    else
      render json: { success: false, message: '無効なlight_keyです' }, status: :bad_request
    end
  end
end 