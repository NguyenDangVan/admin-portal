class CleanupCacheJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info "Starting cache cleanup job"
    
    cache_service = CacheService.instance
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    
    # Clean up old performance metrics
    cleanup_old_metrics(redis)
    
    # Clean up old cache tags
    cleanup_old_cache_tags(redis)
    
    # Clean up expired cache keys
    cleanup_expired_cache_keys(redis)
    
    # Clean up old GDPR records
    cleanup_old_gdpr_records(redis)
    
    Rails.logger.info "Cache cleanup job completed successfully"
    
    # Log the cleanup operation
    AuditLog.create!(
      restaurant_id: nil, # System operation
      action: 'cache_cleanup',
      auditable_type: 'System',
      auditable_id: 'cleanup',
      changes: { cleanup_type: 'scheduled_cache_cleanup' },
      metadata: { 
        job_class: self.class.name,
        execution_time: Time.current.iso8601,
        cleanup_type: 'scheduled'
      }
    )
    
  rescue => e
    Rails.logger.error "Failed to cleanup cache: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Notify administrators of the failure
    notify_cleanup_failure(e)
    
    raise e
  end

  private

  def cleanup_old_metrics(redis)
    Rails.logger.info "Cleaning up old performance metrics"
    
    # Clean up metrics older than 30 days
    cutoff_time = 30.days.ago.to_i
    patterns = ['api_metrics:*', 'db_metrics:*', 'cache_metrics:*', 'job_metrics:*']
    
    patterns.each do |pattern|
      keys = redis.keys(pattern)
      keys.each do |key|
        # Extract timestamp from key (format: type:timestamp)
        parts = key.split(':')
        if parts.length >= 2
          timestamp = parts[1].to_i
          if timestamp < cutoff_time
            redis.del(key)
            Rails.logger.debug "Deleted old metric key: #{key}"
          end
        end
      end
    end
  end

  def cleanup_old_cache_tags(redis)
    Rails.logger.info "Cleaning up old cache tags"
    
    # Clean up cache tags older than 24 hours
    cutoff_time = 24.hours.ago.to_i
    tag_keys = redis.keys("cache_tags:*")
    
    tag_keys.each do |tag_key|
      # Check if tag has expired
      ttl = redis.ttl(tag_key)
      if ttl == -1 # No expiration set
        # Check last access time from metadata
        metadata = redis.get("#{tag_key}:metadata")
        if metadata
          begin
            data = JSON.parse(metadata)
            last_access = data['last_access'].to_i
            if last_access < cutoff_time
              redis.del(tag_key)
              redis.del("#{tag_key}:metadata")
              Rails.logger.debug "Deleted old cache tag: #{tag_key}"
            end
          rescue JSON::ParserError
            # If metadata is corrupted, delete the tag
            redis.del(tag_key)
            redis.del("#{tag_key}:metadata")
          end
        end
      end
    end
  end

  def cleanup_expired_cache_keys(redis)
    Rails.logger.info "Cleaning up expired cache keys"
    
    # This is handled automatically by Redis, but we can clean up any orphaned keys
    # that might not have proper TTL set
    
    # Look for cache keys without proper TTL
    cache_keys = redis.keys("cache:*")
    expired_count = 0
    
    cache_keys.each do |key|
      ttl = redis.ttl(key)
      if ttl == -1 # No expiration set
        # Check if it's an old cache entry
        value = redis.get(key)
        if value
          begin
            data = JSON.parse(value)
            cached_at = data['cached_at']
            if cached_at
              cached_time = Time.parse(cached_at).to_i
              # If older than 1 hour, consider it expired
              if cached_time < 1.hour.ago.to_i
                redis.del(key)
                expired_count += 1
                Rails.logger.debug "Deleted expired cache key: #{key}"
              end
            end
          rescue JSON::ParserError, ArgumentError
            # If we can't parse the data, delete the key
            redis.del(key)
            expired_count += 1
          end
        end
      end
    end
    
    Rails.logger.info "Cleaned up #{expired_count} expired cache keys"
  end

  def cleanup_old_gdpr_records(redis)
    Rails.logger.info "Cleaning up old GDPR records"
    
    # Clean up GDPR exports older than 1 year
    cutoff_time = 1.year.ago.to_i
    gdpr_keys = redis.keys("gdpr_export:*")
    deleted_count = 0
    
    gdpr_keys.each do |key|
      # Extract timestamp from key (format: gdpr_export:user_id:timestamp)
      parts = key.split(':')
      if parts.length >= 3
        timestamp = parts[2].to_i
        if timestamp < cutoff_time
          redis.del(key)
          deleted_count += 1
          Rails.logger.debug "Deleted old GDPR export: #{key}"
        end
      end
    end
    
    Rails.logger.info "Cleaned up #{deleted_count} old GDPR export records"
  end

  def notify_cleanup_failure(error)
    # This would integrate with your notification system
    # For now, just log it
    Rails.logger.error "Cache cleanup failure notification: #{error.message}"
  end
end
