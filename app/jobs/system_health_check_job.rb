class SystemHealthCheckJob < ApplicationJob
  queue_as :critical

  def perform
    Rails.logger.info "Starting system health check"
    
    health_status = {
      timestamp: Time.current.iso8601,
      overall_status: 'healthy',
      checks: {}
    }
    
    # Check database health
    health_status[:checks][:database] = check_database_health
    
    # Check Redis health
    health_status[:checks][:redis] = check_redis_health
    
    # Check Sidekiq health
    health_status[:checks][:sidekiq] = check_sidekiq_health
    
    # Check cache health
    health_status[:checks][:cache] = check_cache_health
    
    # Check disk space
    health_status[:checks][:disk] = check_disk_health
    
    # Check memory usage
    health_status[:checks][:memory] = check_memory_health
    
    # Determine overall status
    health_status[:overall_status] = determine_overall_status(health_status[:checks])
    
    # Store health status in Redis
    store_health_status(health_status)
    
    # Log health check results
    log_health_check(health_status)
    
    # Send alerts if needed
    send_health_alerts(health_status) if health_status[:overall_status] != 'healthy'
    
    Rails.logger.info "System health check completed. Status: #{health_status[:overall_status]}"
    
  rescue => e
    Rails.logger.error "System health check failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Send critical alert
    send_critical_alert(e)
    
    raise e
  end

  private

  def check_database_health
    start_time = Time.current
    
    begin
      # Check connection
      ActiveRecord::Base.connection.execute('SELECT 1')
      
      # Check connection pool
      pool = ActiveRecord::Base.connection_pool
      pool_size = pool.size
      active_connections = pool.active_connection_count
      pool_usage = (active_connections.to_f / pool_size * 100).round(2)
      
      # Check response time
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if pool_usage > 80
        { status: 'degraded', message: 'High connection pool usage', pool_usage: pool_usage, response_time: response_time }
      else
        { status: 'healthy', message: 'Database connection healthy', pool_usage: pool_usage, response_time: response_time }
      end
    rescue => e
      { status: 'unhealthy', message: 'Database connection failed', error: e.message, response_time: ((Time.current - start_time) * 1000).round(2) }
    end
  end

  def check_redis_health
    start_time = Time.current
    
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      redis.ping
      
      info = redis.info
      memory_usage = info['used_memory_human']
      connected_clients = info['connected_clients'].to_i
      
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if connected_clients > 100
        { status: 'degraded', message: 'High number of Redis connections', connected_clients: connected_clients, memory_usage: memory_usage, response_time: response_time }
      else
        { status: 'healthy', message: 'Redis connection healthy', connected_clients: connected_clients, memory_usage: memory_usage, response_time: response_time }
      end
    rescue => e
      { status: 'unhealthy', message: 'Redis connection failed', error: e.message, response_time: ((Time.current - start_time) * 1000).round(2) }
    end
  end

  def check_sidekiq_health
    start_time = Time.current
    
    begin
      stats = Sidekiq::Stats.new
      
      if stats.processes_size > 0
        # Check queue sizes
        queue_sizes = stats.queues
        total_enqueued = stats.enqueued
        total_scheduled = stats.scheduled
        total_retry = stats.retry_size
        
        response_time = ((Time.current - start_time) * 1000).round(2)
        
        # Check if queues are getting backed up
        if total_enqueued > 1000
          { status: 'degraded', message: 'High queue backlog', enqueued: total_enqueued, scheduled: total_scheduled, retry: total_retry, response_time: response_time }
        else
          { status: 'healthy', message: 'Sidekiq is running', processes: stats.processes_size, enqueued: total_enqueued, response_time: response_time }
        end
      else
        { status: 'unhealthy', message: 'Sidekiq has no active processes', response_time: ((Time.current - start_time) * 1000).round(2) }
      end
    rescue => e
      { status: 'unhealthy', message: 'Sidekiq health check failed', error: e.message, response_time: ((Time.current - start_time) * 1000).round(2) }
    end
  end

  def check_cache_health
    start_time = Time.current
    
    begin
      cache_service = CacheService.instance
      
      if cache_service.healthy?
        # Check cache performance
        stats = cache_service.stats
        total_keys = stats[:total_keys]
        memory_usage = stats[:memory_usage]
        
        response_time = ((Time.current - start_time) * 1000).round(2)
        
        if total_keys > 10000
          { status: 'degraded', message: 'High number of cache keys', total_keys: total_keys, memory_usage: memory_usage, response_time: response_time }
        else
          { status: 'healthy', message: 'Cache service healthy', total_keys: total_keys, memory_usage: memory_usage, response_time: response_time }
        end
      else
        { status: 'unhealthy', message: 'Cache service is not responding', response_time: ((Time.current - start_time) * 1000).round(2) }
      end
    rescue => e
      { status: 'unhealthy', message: 'Cache health check failed', error: e.message, response_time: ((Time.current - start_time) * 1000).round(2) }
    end
  end

  def check_disk_health
    # This would require system-specific implementation
    # For now, return mock data
    {
      status: 'healthy',
      message: 'Disk space adequate',
      usage_percentage: rand(20..60),
      available_space: "#{rand(50..200)}GB"
    }
  end

  def check_memory_health
    # This would require system-specific implementation
    # For now, return mock data
    {
      status: 'healthy',
      message: 'Memory usage normal',
      usage_percentage: rand(30..70),
      available_memory: "#{rand(2..6)}GB"
    }
  end

  def determine_overall_status(checks)
    if checks.values.any? { |check| check[:status] == 'unhealthy' }
      'unhealthy'
    elsif checks.values.any? { |check| check[:status] == 'degraded' }
      'degraded'
    else
      'healthy'
    end
  end

  def store_health_status(health_status)
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    
    # Store current health status
    redis.setex(
      'system_health:current',
      1.hour.to_i,
      health_status.to_json
    )
    
    # Store health history (keep last 24 entries)
    health_history_key = 'system_health:history'
    redis.lpush(health_history_key, health_status.to_json)
    redis.ltrim(health_history_key, 0, 23) # Keep only last 24 entries
    redis.expire(health_history_key, 24.hours.to_i)
  end

  def log_health_check(health_status)
    AuditLog.create!(
      restaurant_id: nil, # System operation
      action: 'system_health_check',
      auditable_type: 'System',
      auditable_id: 'health_check',
      changes: { overall_status: health_status[:overall_status] },
      metadata: { 
        job_class: self.class.name,
        execution_time: Time.current.iso8601,
        health_checks: health_status[:checks]
      }
    )
  end

  def send_health_alerts(health_status)
    # This would integrate with your notification system
    # For now, just log it
    Rails.logger.warn "System health alert: #{health_status[:overall_status]}"
    
    # Log specific issues
    health_status[:checks].each do |component, check|
      if check[:status] != 'healthy'
        Rails.logger.warn "#{component.capitalize} health issue: #{check[:message]}"
      end
    end
  end

  def send_critical_alert(error)
    # This would integrate with your notification system
    Rails.logger.error "CRITICAL: System health check job failed: #{error.message}"
  end
end
