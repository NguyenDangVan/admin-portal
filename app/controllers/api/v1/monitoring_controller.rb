module Api
  module V1
    class MonitoringController < ApplicationController
      before_action :authorize_monitoring_access!

      # Get comprehensive performance report
      def performance_report
        time_range = params[:time_range]&.to_i || 1.hour.to_i
        
        report = PerformanceMonitor.instance.performance_report(time_range)
        render json: report
      end

      # Get cache statistics
      def cache_stats
        cache_service = CacheService.instance
        
        stats = {
          cache_health: cache_service.healthy?,
          cache_stats: cache_service.stats,
          cache_operations: {
            total_keys: cache_service.stats[:total_keys],
            memory_usage: cache_service.stats[:memory_usage]
          }
        }

        render json: stats
      end

      # Get system health information
      def system_health
        health_checks = {
          timestamp: Time.current.iso8601,
          database: database_health_check,
          redis: redis_health_check,
          sidekiq: sidekiq_health_check,
          overall_status: 'healthy'
        }

        # Determine overall status
        if health_checks.values.any? { |check| check[:status] == 'unhealthy' }
          health_checks[:overall_status] = 'unhealthy'
        elsif health_checks.values.any? { |check| check[:status] == 'degraded' }
          health_checks[:overall_status] = 'degraded'
        end

        render json: health_checks
      end

      # Export performance metrics
      def export_metrics
        time_range = params[:time_range]&.to_i || 24.hours.to_i
        format = params[:format]&.to_sym || :json
        
        metrics = PerformanceMonitor.instance.export_metrics(time_range, format)
        
        case format
        when :csv
          send_data metrics, 
                    filename: "performance_metrics_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                    type: 'text/csv'
        else
          render json: metrics
        end
      end

      # Get real-time system metrics
      def real_time_metrics
        metrics = {
          timestamp: Time.current.iso8601,
          system_load: system_load_info,
          memory_usage: memory_usage_info,
          database_connections: database_connection_info,
          redis_connections: redis_connection_info,
          active_jobs: sidekiq_job_info
        }

        render json: metrics
      end

      # Get API endpoint performance
      def endpoint_performance
        time_range = params[:time_range]&.to_i || 1.hour.to_i
        endpoint = params[:endpoint]
        
        if endpoint
          # Get specific endpoint performance
          metrics = PerformanceMonitor.instance.get_metrics('api_metrics', time_range)
          endpoint_metrics = filter_endpoint_metrics(metrics, endpoint)
          render json: { endpoint: endpoint, metrics: endpoint_metrics }
        else
          # Get all endpoints performance
          api_summary = PerformanceMonitor.instance.api_performance_summary(time_range)
          render json: api_summary
        end
      end

      # Get database performance metrics
      def database_performance
        time_range = params[:time_range]&.to_i || 1.hour.to_i
        
        db_summary = PerformanceMonitor.instance.database_performance_summary(time_range)
        render json: db_summary
      end

      # Get cache performance metrics
      def cache_performance
        time_range = params[:time_range]&.to_i || 1.hour.to_i
        
        cache_summary = PerformanceMonitor.instance.cache_performance_summary(time_range)
        render json: cache_summary
      end

      # Get background job performance
      def job_performance
        time_range = params[:time_range]&.to_i || 1.hour.to_i
        
        job_summary = PerformanceMonitor.instance.job_performance_summary(time_range)
        render json: job_summary
      end

      # Clean up old metrics
      def cleanup_metrics
        older_than = params[:older_than]&.to_i || 7.days.to_i
        
        # Only admins can cleanup metrics
        unless current_user.admin? || current_user.super_admin?
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        PerformanceMonitor.instance.cleanup_old_metrics(older_than)
        
        render json: { 
          success: true, 
          message: "Cleaned up metrics older than #{older_than} seconds",
          cleanup_timestamp: Time.current.iso8601
        }
      end

      # Get system alerts
      def system_alerts
        alerts = generate_system_alerts
        render json: { alerts: alerts, timestamp: Time.current.iso8601 }
      end

      private

      def authorize_monitoring_access!
        unless current_user.admin? || current_user.super_admin?
          raise Pundit::NotAuthorizedError, "Only admins can access monitoring data"
        end
      end

      def database_health_check
        begin
          # Check database connection
          ActiveRecord::Base.connection.execute('SELECT 1')
          
          # Check connection pool
          pool_size = ActiveRecord::Base.connection_pool.size
          active_connections = ActiveRecord::Base.connection_pool.active_connection_count
          
          if active_connections.to_f / pool_size > 0.8
            { status: 'degraded', message: 'High connection pool usage', pool_usage: "#{active_connections}/#{pool_size}" }
          else
            { status: 'healthy', message: 'Database connection healthy', pool_usage: "#{active_connections}/#{pool_size}" }
          end
        rescue => e
          { status: 'unhealthy', message: 'Database connection failed', error: e.message }
        end
      end

      def redis_health_check
        begin
          redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
          redis.ping
          
          info = redis.info
          memory_usage = info['used_memory_human']
          connected_clients = info['connected_clients']
          
          { 
            status: 'healthy', 
            message: 'Redis connection healthy',
            memory_usage: memory_usage,
            connected_clients: connected_clients
          }
        rescue => e
          { status: 'unhealthy', message: 'Redis connection failed', error: e.message }
        end
      end

      def sidekiq_health_check
        begin
          # Check if Sidekiq is running
          stats = Sidekiq::Stats.new
          
          if stats.processes_size > 0
            { 
              status: 'healthy', 
              message: 'Sidekiq is running',
              processes: stats.processes_size,
              queues: stats.queues.size
            }
          else
            { status: 'degraded', message: 'Sidekiq has no active processes' }
          end
        rescue => e
          { status: 'unhealthy', message: 'Sidekiq health check failed', error: e.message }
        end
      end

      def system_load_info
        # This would require system-specific implementation
        # For now, return mock data
        {
          cpu_usage: rand(20..80),
          load_average: rand(0.1..2.0).round(2),
          uptime: rand(1000..10000)
        }
      end

      def memory_usage_info
        # This would require system-specific implementation
        {
          total_memory: '8GB',
          used_memory: "#{rand(2..6)}GB",
          available_memory: "#{rand(2..6)}GB"
        }
      end

      def database_connection_info
        pool = ActiveRecord::Base.connection_pool
        {
          pool_size: pool.size,
          active_connections: pool.active_connection_count,
          reserved_connections: pool.reserved_connection_count,
          checkout_timeout: pool.checkout_timeout
        }
      end

      def redis_connection_info
        begin
          redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
          info = redis.info
          
          {
            connected_clients: info['connected_clients'],
            used_memory: info['used_memory_human'],
            total_commands_processed: info['total_commands_processed'],
            keyspace_hits: info['keyspace_hits'],
            keyspace_misses: info['keyspace_misses']
          }
        rescue => e
          { error: e.message }
        end
      end

      def sidekiq_job_info
        begin
          stats = Sidekiq::Stats.new
          
          {
            processes: stats.processes_size,
            queues: stats.queues.size,
            enqueued: stats.enqueued,
            scheduled: stats.scheduled,
            retry: stats.retry_size
          }
        rescue => e
          { error: e.message }
        end
      end

      def filter_endpoint_metrics(metrics, endpoint)
        # Filter metrics for specific endpoint
        # This is a simplified implementation
        {
          endpoint: endpoint,
          metrics: metrics
        }
      end

      def generate_system_alerts
        alerts = []
        
        # Check database connections
        db_check = database_health_check
        if db_check[:status] == 'unhealthy'
          alerts << {
            level: 'critical',
            component: 'database',
            message: db_check[:message],
            timestamp: Time.current.iso8601
          }
        end

        # Check Redis health
        redis_check = redis_health_check
        if redis_check[:status] == 'unhealthy'
          alerts << {
            level: 'critical',
            component: 'redis',
            message: redis_check[:message],
            timestamp: Time.current.iso8601
          }
        end

        # Check Sidekiq health
        sidekiq_check = sidekiq_health_check
        if sidekiq_check[:status] == 'unhealthy'
          alerts << {
            level: 'critical',
            component: 'sidekiq',
            message: sidekiq_check[:message],
            timestamp: Time.current.iso8601
          }
        end

        # Check cache health
        cache_service = CacheService.instance
        unless cache_service.healthy?
          alerts << {
            level: 'warning',
            component: 'cache',
            message: 'Cache service is not responding',
            timestamp: Time.current.iso8601
          }
        end

        alerts
      end
    end
  end
end
