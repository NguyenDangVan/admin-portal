# Redis Cache Configuration
Rails.application.configure do
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    connect_timeout: 30,
    read_timeout: 0.2,
    write_timeout: 0.2,
    reconnect_attempts: 1,
    error_handler: -> (method:, returning:, exception:) {
      Rails.logger.error "Redis error: #{exception.class} - #{exception.message}"
      Sentry.capture_exception(exception) if defined?(Sentry)
    }
  }

  # Configure Redis for Action Cable if needed
  config.action_cable.cable_adapter = 'redis'
  config.action_cable.redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
end

# Redis connection pool for Sidekiq
Sidekiq.configure_server do |config|
  config.redis = { 
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    pool_timeout: 5,
    retry_count: 3
  }
end

Sidekiq.configure_client do |config|
  config.redis = { 
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    pool_timeout: 5,
    retry_count: 3
  }
end

# Redis health check
def redis_healthy?
  Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')).ping == 'PONG'
rescue => e
  Rails.logger.error "Redis health check failed: #{e.message}"
  false
end
