class CacheService
  include Singleton

  CACHE_TTL = {
    dashboard: 10.minutes,
    sales_analytics: 5.minutes,
    employee_performance: 15.minutes,
    inventory_insights: 30.minutes,
    financial_summary: 10.minutes,
    restaurant_stats: 5.minutes,
    user_permissions: 1.hour,
    api_responses: 2.minutes
  }.freeze

  def initialize
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end

  # Cache data with intelligent TTL
  def cache(key, data, ttl: nil, tags: [])
    ttl ||= CACHE_TTL[:api_responses]
    
    cache_data = {
      data: data,
      cached_at: Time.current.iso8601,
      version: cache_version
    }

    @redis.setex(key, ttl.to_i, cache_data.to_json)
    
    # Store tags for invalidation
    if tags.any?
      tags.each do |tag|
        @redis.sadd("cache_tags:#{tag}", key)
        @redis.expire("cache_tags:#{tag}", 24.hours.to_i)
      end
    end

    data
  end

  # Get cached data
  def get(key)
    cached = @redis.get(key)
    return nil unless cached

    begin
      parsed = JSON.parse(cached)
      parsed['data']
    rescue JSON::ParserError
      @redis.del(key)
      nil
    end
  end

  # Get cached data with metadata
  def get_with_metadata(key)
    cached = @redis.get(key)
    return nil unless cached

    begin
      JSON.parse(cached)
    rescue JSON::ParserError
      @redis.del(key)
      nil
    end
  end

  # Check if cache exists and is fresh
  def exists?(key)
    @redis.exists?(key)
  end

  # Delete specific cache key
  def delete(key)
    @redis.del(key)
  end

  # Invalidate cache by tags
  def invalidate_by_tags(*tags)
    tags.each do |tag|
      keys = @redis.smembers("cache_tags:#{tag}")
      keys.each { |key| @redis.del(key) }
      @redis.del("cache_tags:#{tag}")
    end
  end

  # Invalidate cache by pattern
  def invalidate_by_pattern(pattern)
    keys = @redis.keys(pattern)
    @redis.del(*keys) if keys.any?
  end

  # Invalidate restaurant-specific cache
  def invalidate_restaurant(restaurant_id)
    patterns = [
      "dashboard_#{restaurant_id}_*",
      "sales_analytics_#{restaurant_id}_*",
      "employee_performance_#{restaurant_id}_*",
      "inventory_insights_#{restaurant_id}_*",
      "financial_summary_#{restaurant_id}_*",
      "restaurant_stats_#{restaurant_id}_*"
    ]

    patterns.each { |pattern| invalidate_by_pattern(pattern) }
    invalidate_by_tags("restaurant:#{restaurant_id}")
  end

  # Invalidate user-specific cache
  def invalidate_user(user_id)
    patterns = [
      "user_permissions_#{user_id}",
      "user_activity_#{user_id}_*"
    ]

    patterns.each { |pattern| invalidate_by_pattern(pattern) }
    invalidate_by_tags("user:#{user_id}")
  end

  # Cache with automatic invalidation
  def smart_cache(key, data, options = {})
    ttl = options[:ttl] || CACHE_TTL[:api_responses]
    tags = options[:tags] || []
    
    # Add automatic tags based on data
    if data.respond_to?(:restaurant_id)
      tags << "restaurant:#{data.restaurant_id}"
    end
    
    if data.respond_to?(:user_id)
      tags << "user:#{data.user_id}"
    end

    cache(key, data, ttl: ttl, tags: tags)
  end

  # Cache with conditional logic
  def conditional_cache(key, condition, data, options = {})
    return data unless condition
    
    smart_cache(key, data, options)
  end

  # Cache with fallback
  def cache_with_fallback(key, fallback_proc, options = {})
    cached = get(key)
    return cached if cached

    data = fallback_proc.call
    smart_cache(key, data, options)
    data
  end

  # Batch cache operations
  def batch_cache(cache_operations)
    pipeline = @redis.pipeline
    
    cache_operations.each do |operation|
      key = operation[:key]
      data = operation[:data]
      ttl = operation[:ttl] || CACHE_TTL[:api_responses]
      tags = operation[:tags] || []
      
      cache_data = {
        data: data,
        cached_at: Time.current.iso8601,
        version: cache_version
      }
      
      pipeline.setex(key, ttl.to_i, cache_data.to_json)
      
      tags.each do |tag|
        pipeline.sadd("cache_tags:#{tag}", key)
        pipeline.expire("cache_tags:#{tag}", 24.hours.to_i)
      end
    end
    
    pipeline.exec
  end

  # Cache statistics
  def stats
    {
      total_keys: @redis.dbsize,
      memory_usage: @redis.info['used_memory_human'],
      hit_rate: calculate_hit_rate,
      cache_size: calculate_cache_size
    }
  end

  # Clear all cache
  def clear_all
    @redis.flushdb
  end

  # Health check
  def healthy?
    @redis.ping == 'PONG'
  rescue => e
    Rails.logger.error "Cache service health check failed: #{e.message}"
    false
  end

  private

  def cache_version
    Rails.application.config.cache_version || '1.0'
  end

  def calculate_hit_rate
    # This would require additional tracking in a real implementation
    'N/A'
  end

  def calculate_cache_size
    @redis.dbsize
  end
end
