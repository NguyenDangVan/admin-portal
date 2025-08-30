class PerformanceMonitor
  include Singleton

  def initialize
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    @metrics = {}
  end

  # Track API request performance
  def track_request(endpoint, duration, status, user_id = nil, restaurant_id = nil)
    timestamp = Time.current.to_i
    key = "api_metrics:#{endpoint}:#{timestamp / 300}" # 5-minute buckets
    
    metrics = {
      count: 1,
      total_duration: duration,
      avg_duration: duration,
      min_duration: duration,
      max_duration: duration,
      success_count: status < 400 ? 1 : 0,
      error_count: status >= 400 ? 1 : 0,
      user_id: user_id,
      restaurant_id: restaurant_id
    }

    update_metrics(key, metrics)
  end

  # Track database query performance
  def track_query(sql, duration, table_name = nil)
    timestamp = Time.current.to_i
    key = "db_metrics:#{table_name || 'unknown'}:#{timestamp / 300}"
    
    metrics = {
      count: 1,
      total_duration: duration,
      avg_duration: duration,
      min_duration: duration,
      max_duration: duration,
      sql: sql[0..100] # Truncate long SQL queries
    }

    update_metrics(key, metrics)
  end

  # Track cache performance
  def track_cache_operation(operation, key, hit, duration = nil)
    timestamp = Time.current.to_i
    cache_key = "cache_metrics:#{operation}:#{timestamp / 300}"
    
    metrics = {
      count: 1,
      hits: hit ? 1 : 0,
      misses: hit ? 0 : 1,
      total_duration: duration || 0,
      avg_duration: duration || 0
    }

    update_metrics(cache_key, metrics)
  end

  # Track background job performance
  def track_job(job_class, duration, success, error_message = nil)
    timestamp = Time.current.to_i
    key = "job_metrics:#{job_class}:#{timestamp / 300}"
    
    metrics = {
      count: 1,
      total_duration: duration,
      avg_duration: duration,
      success_count: success ? 1 : 0,
      error_count: success ? 0 : 1,
      last_error: error_message
    }

    update_metrics(key, metrics)
  end

  # Get performance metrics
  def get_metrics(type, time_range = 1.hour)
    end_time = Time.current.to_i
    start_time = end_time - time_range.to_i
    
    keys = []
    current_time = start_time
    
    while current_time <= end_time
      bucket = current_time / 300
      keys << "#{type}:#{bucket}"
      current_time += 300
    end

    aggregate_metrics(keys)
  end

  # Get API performance summary
  def api_performance_summary(time_range = 1.hour)
    metrics = get_metrics('api_metrics', time_range)
    
    {
      total_requests: metrics[:count] || 0,
      average_response_time: metrics[:avg_duration] || 0,
      success_rate: calculate_success_rate(metrics),
      top_endpoints: get_top_endpoints(time_range),
      response_time_distribution: get_response_time_distribution(time_range)
    }
  end

  # Get database performance summary
  def database_performance_summary(time_range = 1.hour)
    metrics = get_metrics('db_metrics', time_range)
    
    {
      total_queries: metrics[:count] || 0,
      average_query_time: metrics[:avg_duration] || 0,
      slowest_tables: get_slowest_tables(time_range),
      query_frequency: get_query_frequency(time_range)
    }
  end

  # Get cache performance summary
  def cache_performance_summary(time_range = 1.hour)
    metrics = get_metrics('cache_metrics', time_range)
    
    {
      total_operations: metrics[:count] || 0,
      hit_rate: calculate_hit_rate(metrics),
      average_operation_time: metrics[:avg_duration] || 0,
      operation_breakdown: get_operation_breakdown(time_range)
    }
  end

  # Get background job performance summary
  def job_performance_summary(time_range = 1.hour)
    metrics = get_metrics('job_metrics', time_range)
    
    {
      total_jobs: metrics[:count] || 0,
      success_rate: calculate_job_success_rate(metrics),
      average_job_time: metrics[:avg_duration] || 0,
      job_breakdown: get_job_breakdown(time_range)
    }
  end

  # Get comprehensive performance report
  def performance_report(time_range = 1.hour)
    {
      timestamp: Time.current.iso8601,
      time_range: time_range,
      api: api_performance_summary(time_range),
      database: database_performance_summary(time_range),
      cache: cache_performance_summary(time_range),
      background_jobs: job_performance_summary(time_range),
      system_health: system_health_check
    }
  end

  # Clean up old metrics
  def cleanup_old_metrics(older_than = 7.days)
    cutoff_time = Time.current.to_i - older_than.to_i
    cutoff_bucket = cutoff_time / 300
    
    patterns = ['api_metrics:*', 'db_metrics:*', 'cache_metrics:*', 'job_metrics:*']
    
    patterns.each do |pattern|
      keys = @redis.keys(pattern)
      keys.each do |key|
        bucket = key.split(':').last.to_i
        @redis.del(key) if bucket < cutoff_bucket
      end
    end
  end

  # Export metrics for analysis
  def export_metrics(time_range = 24.hours, format = :json)
    data = performance_report(time_range)
    
    case format
    when :json
      data.to_json
    when :csv
      metrics_to_csv(data)
    else
      data
    end
  end

  private

  def update_metrics(key, new_metrics)
    existing = @redis.get(key)
    
    if existing
      begin
        current = JSON.parse(existing)
        updated = merge_metrics(current, new_metrics)
        @redis.setex(key, 3600, updated.to_json) # 1 hour TTL
      rescue JSON::ParserError
        @redis.setex(key, 3600, new_metrics.to_json)
      end
    else
      @redis.setex(key, 3600, new_metrics.to_json)
    end
  end

  def merge_metrics(current, new_metrics)
    merged = {}
    
    new_metrics.each do |key, value|
      if current[key].is_a?(Numeric) && value.is_a?(Numeric)
        case key
        when :count, :success_count, :error_count, :hits, :misses
          merged[key] = current[key] + value
        when :total_duration
          merged[key] = current[key] + value
        when :avg_duration
          merged[key] = (current[:total_duration] + value) / (current[:count] + 1)
        when :min_duration
          merged[key] = [current[key], value].min
        when :max_duration
          merged[key] = [current[key], value].max
        else
          merged[key] = value
        end
      else
        merged[key] = value
      end
    end
    
    merged
  end

  def aggregate_metrics(keys)
    aggregated = {}
    
    keys.each do |key|
      data = @redis.get(key)
      next unless data
      
      begin
        metrics = JSON.parse(data)
        aggregated = merge_metrics(aggregated, metrics)
      rescue JSON::ParserError
        next
      end
    end
    
    aggregated
  end

  def calculate_success_rate(metrics)
    return 0 if metrics[:count].to_i == 0
    (metrics[:success_count].to_f / metrics[:count].to_f * 100).round(2)
  end

  def calculate_hit_rate(metrics)
    return 0 if metrics[:count].to_i == 0
    (metrics[:hits].to_f / metrics[:count].to_f * 100).round(2)
  end

  def calculate_job_success_rate(metrics)
    return 0 if metrics[:count].to_i == 0
    (metrics[:success_count].to_f / metrics[:count].to_f * 100).round(2)
  end

  def get_top_endpoints(time_range)
    # Implementation for getting top endpoints by request count
    {}
  end

  def get_response_time_distribution(time_range)
    # Implementation for response time distribution
    {}
  end

  def get_slowest_tables(time_range)
    # Implementation for getting slowest database tables
    {}
  end

  def get_query_frequency(time_range)
    # Implementation for query frequency analysis
    {}
  end

  def get_operation_breakdown(time_range)
    # Implementation for cache operation breakdown
    {}
  end

  def get_job_breakdown(time_range)
    # Implementation for job breakdown analysis
    {}
  end

  def system_health_check
    {
      redis_healthy: @redis.ping == 'PONG',
      memory_usage: @redis.info['used_memory_human'],
      uptime: @redis.info['uptime_in_seconds']
    }
  rescue => e
    {
      redis_healthy: false,
      error: e.message
    }
  end

  def metrics_to_csv(data)
    require 'csv'
    
    CSV.generate do |csv|
      csv << ['Metric', 'Value']
      flatten_hash(data).each do |key, value|
        csv << [key, value]
      end
    end
  end

  def flatten_hash(hash, prefix = '')
    hash.flat_map do |key, value|
      new_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        flatten_hash(value, new_key)
      else
        [[new_key, value]]
      end
    end
  end
end
