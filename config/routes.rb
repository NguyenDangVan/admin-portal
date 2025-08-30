Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      # Restaurant management
      resources :restaurants, only: [:index, :show, :create, :update, :destroy] do
        member do
          get :dashboard
        end
        
        # Nested resources
        resources :employees, only: [:index, :show, :create, :update, :destroy] do
          collection do
            get :performance_report
            post :import
          end
        end
        
        resources :transactions, only: [:index, :show, :create, :update, :destroy] do
          collection do
            get :daily_sales_report
            get :sales_summary
            post :import
          end
        end
        
        resources :discounts, only: [:index, :show, :create, :update, :destroy] do
          collection do
            get :calculate
            get :summary
            patch :bulk_update
          end
        end
        
        # Reports
        namespace :reports do
          get :dashboard
          get :sales_analytics
          get :employee_performance
          get :inventory_insights
          get :financial_summary
          get :export_report
        end
      end
      
      # Authentication (placeholder for Supabase integration)
      namespace :auth do
        post :login
        post :logout
        get :me
      end

      # GDPR Compliance endpoints
      namespace :gdpr do
        get :export_data
        post :anonymize_data
        delete :delete_data
        get :check_consent
        post :record_consent
        delete :withdraw_consent
        get :retention_info
        get :processing_activities
        get :subject_rights
        get :security_measures
        get :breach_procedures
        get :compliance_report
        patch :request_rectification
        post :object_to_processing
      end

      # Performance monitoring endpoints
      namespace :monitoring do
        get :performance_report
        get :cache_stats
        get :system_health
        get :export_metrics
      end
    end
  end

  # GraphQL endpoint
  post "/graphql", to: "graphql#execute"
  
  # GraphQL playground in development
  if Rails.env.development?
    get "/graphql", to: "graphql#playground"
  end

  # Sidekiq dashboard
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  # Health check endpoint
  get '/health', to: proc { [200, {}, ['OK']] }
  
  # Root redirect to API docs
  root 'api/v1/restaurants#index'
end
