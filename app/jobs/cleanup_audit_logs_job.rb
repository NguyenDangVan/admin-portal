class CleanupAuditLogsJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info "Starting cleanup of old audit logs"
    
    # Keep audit logs for 7 years (GDPR compliance)
    cutoff_date = 7.years.ago
    
    # Find old audit logs
    old_logs = AuditLog.where('created_at < ?', cutoff_date)
    count = old_logs.count
    
    if count > 0
      Rails.logger.info "Found #{count} old audit logs to delete"
      
      # Delete in batches to avoid memory issues
      old_logs.find_in_batches(batch_size: 1000) do |batch|
        batch.each do |log|
          # Store deletion record before actual deletion
          store_deletion_record(log)
        end
        
        # Delete the batch
        AuditLog.where(id: batch.map(&:id)).delete_all
      end
      
      Rails.logger.info "Successfully deleted #{count} old audit logs"
    else
      Rails.logger.info "No old audit logs found for cleanup"
    end
    
    # Log the cleanup operation
    AuditLog.create!(
      restaurant_id: nil, # System operation
      action: 'audit_logs_cleanup',
      auditable_type: 'System',
      auditable_id: 'cleanup',
      changes: { deleted_count: count, cutoff_date: cutoff_date.iso8601 },
      metadata: { 
        job_class: self.class.name,
        execution_time: Time.current.iso8601,
        cleanup_type: 'scheduled'
      }
    )
    
  rescue => e
    Rails.logger.error "Failed to cleanup audit logs: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Notify administrators of the failure
    notify_cleanup_failure(e)
    
    raise e
  end

  private

  def store_deletion_record(audit_log)
    # Store deletion record in Redis for compliance
    deletion_record = {
      audit_log_id: audit_log.id,
      deleted_at: Time.current.iso8601,
      original_data: audit_log.attributes,
      deletion_reason: 'Scheduled cleanup - GDPR compliance'
    }
    
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    redis.setex(
      "deleted_audit_log:#{audit_log.id}",
      7.years.to_i,
      deletion_record.to_json
    )
  end

  def notify_cleanup_failure(error)
    # This would integrate with your notification system
    # For now, just log it
    Rails.logger.error "Cleanup failure notification: #{error.message}"
  end
end
