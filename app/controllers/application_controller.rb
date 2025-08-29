class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  
  before_action :authenticate_user!
  before_action :set_current_restaurant
  
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from JWT::DecodeError, with: :unauthorized
  rescue_from JWT::ExpiredSignature, with: :unauthorized

  private

  def authenticate_user!
    @current_user = authenticate_jwt_token
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
  end

  def authenticate_jwt_token
    token = extract_token_from_header
    return nil unless token

    begin
      decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
      user_data = decoded_token.first
      User.find_by(supabase_uid: user_data['sub'])
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end

  def extract_token_from_header
    authorization_header = request.headers['Authorization']
    return nil unless authorization_header

    token = authorization_header.split(' ').last
    token if token.present?
  end

  def set_current_restaurant
    return unless @current_user&.restaurant_id

    # Set PostgreSQL session variable for RLS policies
    ActiveRecord::Base.connection.execute(
      "SET app.current_restaurant = '#{@current_user.restaurant_id}'"
    )
  end

  def current_user
    @current_user
  end

  def current_restaurant
    @current_user&.restaurant
  end

  def not_found(exception)
    render json: {
      error: {
        code: 'NOT_FOUND',
        message: 'Resource not found',
        details: exception.message
      }
    }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        details: exception.record.errors.full_messages
      }
    }, status: :unprocessable_entity
  end

  def forbidden(exception)
    render json: {
      error: {
        code: 'FORBIDDEN',
        message: 'Access denied',
        details: exception.message
      }
    }, status: :forbidden
  end

  def unauthorized(exception)
    render json: {
      error: {
        code: 'UNAUTHORIZED',
        message: 'Authentication required',
        details: exception.message
      }
    }, status: :unauthorized
  end

  def paginate(collection, page: 1, per_page: 20)
    page = [page.to_i, 1].max
    per_page = [per_page.to_i, 100].clamp(1, 100)
    
    # Simple pagination without external gems
    offset = (page - 1) * per_page
    collection.limit(per_page).offset(offset)
  end

  def render_paginated(collection, serializer: nil)
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20
    
    paginated = paginate(collection, page: page, per_page: per_page)
    total_count = collection.count
    
    render json: {
      data: paginated,
      pagination: {
        current_page: page,
        total_pages: (total_count.to_f / per_page).ceil,
        total_count: total_count,
        per_page: per_page
      }
    }
  end
end
