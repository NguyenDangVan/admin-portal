class GDPRService
  include Singleton

  def initialize
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end

  # Export all user data for GDPR compliance
  def export_user_data(user_id)
    user = User.find(user_id)
    return { error: 'User not found' } unless user

    data = {
      user: user_data_export(user),
      activity: user_activity_export(user),
      transactions: user_transaction_export(user),
      audit_logs: user_audit_export(user),
      export_timestamp: Time.current.iso8601,
      export_id: SecureRandom.uuid
    }

    # Store export for audit purposes
    store_export_record(user_id, data)
    
    data
  end

  # Anonymize user data (right to be forgotten)
  def anonymize_user_data(user_id)
    user = User.find(user_id)
    return { error: 'User not found' } unless user

    begin
      ActiveRecord::Base.transaction do
        # Anonymize user data
        user.update!(
          first_name: 'Anonymous',
          last_name: 'User',
          email: "anonymous_#{SecureRandom.hex(8)}@deleted.com",
          supabase_uid: "deleted_#{SecureRandom.hex(8)}",
          active: false
        )

        # Anonymize audit logs
        AuditLog.where(user_id: user_id).update_all(
          user_id: nil,
          metadata: { anonymized: true, original_user_id: user_id, anonymized_at: Time.current.iso8601 }
        )

        # Anonymize transactions (if user was an employee)
        if user.employee
          Transaction.where(employee_id: user.employee.id).update_all(
            notes: "Employee data anonymized for GDPR compliance"
          )
        end

        # Log the anonymization
        AuditLog.create!(
          restaurant_id: user.restaurant_id,
          action: 'user_data_anonymized',
          auditable_type: 'User',
          auditable_id: user.id,
          changes: { anonymized: true, original_user_id: user_id },
          metadata: { gdpr_compliance: true, anonymized_at: Time.current.iso8601 }
        )

        # Invalidate related cache
        CacheService.instance.invalidate_user(user_id)
      end

      { success: true, message: 'User data anonymized successfully', user_id: user_id }
    rescue => e
      { error: 'Failed to anonymize user data', details: e.message }
    end
  end

  # Delete user data completely (if required by law)
  def delete_user_data(user_id)
    user = User.find(user_id)
    return { error: 'User not found' } unless user

    begin
      ActiveRecord::Base.transaction do
        # Store deletion record before actual deletion
        deletion_record = {
          user_id: user_id,
          deleted_at: Time.current.iso8601,
          deletion_reason: 'GDPR compliance - right to be forgotten',
          data_snapshot: export_user_data(user_id)
        }

        @redis.setex("gdpr_deletion:#{user_id}", 7.years.to_i, deletion_record.to_json)

        # Delete user and related data
        user.destroy

        # Log the deletion
        AuditLog.create!(
          restaurant_id: user.restaurant_id,
          action: 'user_data_deleted',
          auditable_type: 'User',
          auditable_id: user_id,
          changes: { deleted: true, deletion_reason: 'GDPR compliance' },
          metadata: { gdpr_compliance: true, deleted_at: Time.current.iso8601 }
        )
      end

      { success: true, message: 'User data deleted successfully', user_id: user_id }
    rescue => e
      { error: 'Failed to delete user data', details: e.message }
    end
  end

  # Get data retention information
  def data_retention_info
    {
      user_data: {
        retention_period: '7 years',
        reason: 'Legal and business requirements',
        deletion_policy: 'Automatic deletion after retention period'
      },
      transaction_data: {
        retention_period: '7 years',
        reason: 'Tax and legal compliance',
        deletion_policy: 'Anonymization after 3 years, deletion after 7 years'
      },
      audit_logs: {
        retention_period: '7 years',
        reason: 'Legal compliance and security',
        deletion_policy: 'Automatic deletion after retention period'
      },
      analytics_data: {
        retention_period: '2 years',
        reason: 'Business intelligence',
        deletion_policy: 'Aggregation after 1 year, deletion after 2 years'
      }
    }
  end

  # Check data processing consent
  def check_consent(user_id, processing_purpose)
    user = User.find(user_id)
    return { error: 'User not found' } unless user

    consent_key = "consent:#{user_id}:#{processing_purpose}"
    consent_data = @redis.get(consent_key)

    if consent_data
      consent = JSON.parse(consent_data)
      {
        has_consent: consent['granted'],
        consent_date: consent['date'],
        consent_version: consent['version'],
        can_withdraw: consent['can_withdraw']
      }
    else
      { has_consent: false, message: 'No consent record found' }
    end
  end

  # Record user consent
  def record_consent(user_id, processing_purpose, granted, version = '1.0')
    consent_data = {
      user_id: user_id,
      processing_purpose: processing_purpose,
      granted: granted,
      date: Time.current.iso8601,
      version: version,
      can_withdraw: true
    }

    consent_key = "consent:#{user_id}:#{processing_purpose}"
    @redis.setex(consent_key, 7.years.to_i, consent_data.to_json)

    # Log consent
    AuditLog.create!(
      restaurant_id: User.find(user_id).restaurant_id,
      action: 'consent_recorded',
      auditable_type: 'User',
      auditable_id: user_id,
      changes: { processing_purpose: processing_purpose, granted: granted },
      metadata: { gdpr_compliance: true, consent_version: version }
    )

    { success: true, consent_recorded: true }
  end

  # Withdraw consent
  def withdraw_consent(user_id, processing_purpose)
    consent_key = "consent:#{user_id}:#{processing_purpose}"
    consent_data = @redis.get(consent_key)

    if consent_data
      consent = JSON.parse(consent_data)
      consent['withdrawn_at'] = Time.current.iso8601
      consent['granted'] = false

      @redis.setex(consent_key, 7.years.to_i, consent.to_json)

      # Log withdrawal
      AuditLog.create!(
        restaurant_id: User.find(user_id).restaurant_id,
        action: 'consent_withdrawn',
        auditable_type: 'User',
        auditable_id: user_id,
        changes: { processing_purpose: processing_purpose, withdrawn: true },
        metadata: { gdpr_compliance: true, withdrawn_at: Time.current.iso8601 }
      )

      { success: true, consent_withdrawn: true }
    else
      { error: 'No consent record found' }
    end
  end

  # Get data processing activities
  def data_processing_activities
    {
      user_management: {
        purpose: 'User account management and authentication',
        legal_basis: 'Contract performance',
        data_categories: ['Personal identification', 'Contact information', 'Authentication data'],
        retention_period: '7 years',
        third_party_sharing: false
      },
      transaction_processing: {
        purpose: 'Payment processing and order fulfillment',
        legal_basis: 'Contract performance',
        data_categories: ['Payment information', 'Order details', 'Transaction history'],
        retention_period: '7 years',
        third_party_sharing: 'Payment processors only'
      },
      analytics: {
        purpose: 'Business intelligence and performance improvement',
        legal_basis: 'Legitimate interest',
        data_categories: ['Aggregated transaction data', 'Performance metrics', 'Usage patterns'],
        retention_period: '2 years',
        third_party_sharing: false
      },
      customer_support: {
        purpose: 'Customer service and issue resolution',
        legal_basis: 'Contract performance',
        data_categories: ['Contact information', 'Issue details', 'Communication history'],
        retention_period: '3 years',
        third_party_sharing: false
      }
    }
  end

  # Generate GDPR compliance report
  def compliance_report(restaurant_id = nil)
    report = {
      generated_at: Time.current.iso8601,
      data_retention: data_retention_info,
      processing_activities: data_processing_activities,
      consent_management: consent_summary(restaurant_id),
      data_subject_rights: data_subject_rights_info,
      security_measures: security_measures_info,
      breach_procedures: breach_procedures_info
    }

    # Store report
    report_key = "gdpr_report:#{restaurant_id || 'global'}:#{Time.current.to_i}"
    @redis.setex(report_key, 7.years.to_i, report.to_json)

    report
  end

  # Data subject rights information
  def data_subject_rights_info
    {
      right_to_access: {
        description: 'Users can request access to their personal data',
        implementation: 'Export user data via API endpoint',
        response_time: '30 days'
      },
      right_to_rectification: {
        description: 'Users can request correction of inaccurate data',
        implementation: 'Update user profile via API',
        response_time: '30 days'
      },
      right_to_erasure: {
        description: 'Users can request deletion of their data',
        implementation: 'Anonymize or delete user data',
        response_time: '30 days'
      },
      right_to_portability: {
        description: 'Users can request data in portable format',
        implementation: 'Export data in JSON/CSV format',
        response_time: '30 days'
      },
      right_to_object: {
        description: 'Users can object to data processing',
        implementation: 'Withdraw consent and stop processing',
        response_time: '30 days'
      }
    }
  end

  # Security measures information
  def security_measures_info
    {
      data_encryption: {
        at_rest: 'AES-256 encryption for sensitive data',
        in_transit: 'TLS 1.3 for all communications',
        database: 'PostgreSQL with encryption at rest'
      },
      access_control: {
        authentication: 'JWT-based authentication',
        authorization: 'Role-based access control (RBAC)',
        audit_logging: 'Comprehensive audit trail for all actions'
      },
      data_isolation: {
        multi_tenant: 'PostgreSQL Row-Level Security (RLS)',
        user_separation: 'Complete data isolation between restaurants'
      },
      monitoring: {
        security_events: 'Real-time security event monitoring',
        access_logs: 'Detailed access and activity logging',
        anomaly_detection: 'Behavioral analysis for suspicious activities'
      }
    }
  end

  # Data breach procedures
  def breach_procedures_info
    {
      detection: {
        automated_monitoring: 'Real-time security monitoring',
        manual_review: 'Regular security audits and reviews',
        incident_response: '24/7 incident response team'
      },
      notification: {
        internal: 'Immediate notification to security team',
        regulatory: '72-hour notification to authorities',
        affected_users: 'Notification within 72 hours'
      },
      containment: {
        immediate_action: 'Isolate affected systems',
        investigation: 'Forensic analysis and root cause identification',
        remediation: 'Implement security fixes and patches'
      },
      recovery: {
        system_restoration: 'Restore systems from secure backups',
        security_enhancement: 'Implement additional security measures',
        lessons_learned: 'Document and apply lessons learned'
      }
    }
  end

  private

  def user_data_export(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      restaurant_id: user.restaurant_id,
      active: user.active,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def user_activity_export(user)
    AuditLog.where(user_id: user.id)
            .order(created_at: :desc)
            .limit(1000)
            .map(&:summary)
  end

  def user_transaction_export(user)
    return [] unless user.employee

    Transaction.where(employee_id: user.employee.id)
               .order(transaction_time: :desc)
               .limit(1000)
               .map(&:summary)
  end

  def user_audit_export(user)
    AuditLog.where(auditable_type: 'User', auditable_id: user.id)
            .order(created_at: :desc)
            .map(&:summary)
  end

  def store_export_record(user_id, data)
    export_key = "gdpr_export:#{user_id}:#{Time.current.to_i}"
    @redis.setex(export_key, 7.years.to_i, data.to_json)
  end

  def consent_summary(restaurant_id)
    if restaurant_id
      users = User.where(restaurant_id: restaurant_id)
    else
      users = User.all
    end

    total_users = users.count
    consent_records = @redis.keys("consent:*").count

    {
      total_users: total_users,
      consent_records: consent_records,
      consent_coverage: total_users > 0 ? (consent_records.to_f / total_users * 100).round(2) : 0
    }
  end
end
