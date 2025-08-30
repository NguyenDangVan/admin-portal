module Api
  module V1
    class GDPRController < ApplicationController
      before_action :set_restaurant
      before_action :authorize_gdpr_access!

      # Export user data (Right to Access)
      def export_data
        user_id = params[:user_id] || current_user.id
        
        # Users can only export their own data unless they're admin
        unless current_user.admin? || current_user.super_admin? || current_user.id.to_s == user_id.to_s
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        data = GDPRService.instance.export_user_data(user_id)
        
        if data[:error]
          render json: data, status: :not_found
        else
          render json: data
        end
      end

      # Anonymize user data (Right to be Forgotten)
      def anonymize_data
        user_id = params[:user_id]
        
        # Only admins can anonymize other users' data
        unless current_user.admin? || current_user.super_admin?
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        result = GDPRService.instance.anonymize_user_data(user_id)
        
        if result[:success]
          render json: result
        else
          render json: result, status: :unprocessable_entity
        end
      end

      # Delete user data completely
      def delete_data
        user_id = params[:user_id]
        
        # Only super admins can completely delete user data
        unless current_user.super_admin?
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        result = GDPRService.instance.delete_user_data(user_id)
        
        if result[:success]
          render json: result
        else
          render json: result, status: :unprocessable_entity
        end
      end

      # Check data processing consent
      def check_consent
        user_id = params[:user_id] || current_user.id
        processing_purpose = params[:processing_purpose]
        
        unless processing_purpose
          return render json: { error: 'Processing purpose is required' }, status: :unprocessable_entity
        end

        # Users can only check their own consent unless they're admin
        unless current_user.admin? || current_user.super_admin? || current_user.id.to_s == user_id.to_s
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        consent_info = GDPRService.instance.check_consent(user_id, processing_purpose)
        render json: consent_info
      end

      # Record user consent
      def record_consent
        user_id = params[:user_id] || current_user.id
        processing_purpose = params[:processing_purpose]
        granted = params[:granted]
        version = params[:version] || '1.0'
        
        unless processing_purpose && granted != nil
          return render json: { error: 'Processing purpose and granted status are required' }, status: :unprocessable_entity
        end

        # Users can only record their own consent unless they're admin
        unless current_user.admin? || current_user.super_admin? || current_user.id.to_s == user_id.to_s
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        result = GDPRService.instance.record_consent(user_id, processing_purpose, granted, version)
        render json: result
      end

      # Withdraw consent
      def withdraw_consent
        user_id = params[:user_id] || current_user.id
        processing_purpose = params[:processing_purpose]
        
        unless processing_purpose
          return render json: { error: 'Processing purpose is required' }, status: :unprocessable_entity
        end

        # Users can only withdraw their own consent unless they're admin
        unless current_user.admin? || current_user.super_admin? || current_user.id.to_s == user_id.to_s
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        result = GDPRService.instance.withdraw_consent(user_id, processing_purpose)
        
        if result[:success]
          render json: result
        else
          render json: result, status: :unprocessable_entity
        end
      end

      # Get data retention information
      def retention_info
        retention_info = GDPRService.instance.data_retention_info
        render json: retention_info
      end

      # Get data processing activities
      def processing_activities
        activities = GDPRService.instance.data_processing_activities
        render json: activities
      end

      # Get data subject rights information
      def subject_rights
        rights = GDPRService.instance.data_subject_rights_info
        render json: rights
      end

      # Get security measures information
      def security_measures
        measures = GDPRService.instance.security_measures_info
        render json: measures
      end

      # Get breach procedures
      def breach_procedures
        procedures = GDPRService.instance.breach_procedures_info
        render json: procedures
      end

      # Generate compliance report
      def compliance_report
        # Only admins can generate compliance reports
        unless current_user.admin? || current_user.super_admin?
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        time_range = params[:time_range]&.to_i || 1.hour.to_i
        report = GDPRService.instance.compliance_report(@restaurant&.id)
        
        render json: report
      end

      # Request data rectification
      def request_rectification
        user_id = params[:user_id] || current_user.id
        field_name = params[:field_name]
        new_value = params[:new_value]
        reason = params[:reason]
        
        unless field_name && new_value
          return render json: { error: 'Field name and new value are required' }, status: :unprocessable_entity
        end

        # Users can only request rectification of their own data unless they're admin
        unless current_user.admin? || current_user.super_admin? || current_user.id.to_s == user_id.to_s
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        user = User.find(user_id)
        
        if user.update(field_name => new_value)
          # Log the rectification request
          AuditLog.create!(
            restaurant_id: user.restaurant_id,
            user_id: current_user.id,
            action: 'data_rectification_requested',
            auditable_type: 'User',
            auditable_id: user.id,
            changes: { field_name: field_name, new_value: new_value, reason: reason },
            metadata: { gdpr_compliance: true, rectification_requested_at: Time.current.iso8601 }
          )

          render json: { 
            success: true, 
            message: 'Data rectification request processed successfully',
            field_updated: field_name,
            new_value: new_value
          }
        else
          render json: { 
            error: 'Failed to update data', 
            details: user.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end

      # Object to data processing
      def object_to_processing
        user_id = params[:user_id] || current_user.id
        processing_purpose = params[:processing_purpose]
        reason = params[:reason]
        
        unless processing_purpose
          return render json: { error: 'Processing purpose is required' }, status: :unprocessable_entity
        end

        # Users can only object to processing of their own data unless they're admin
        unless current_user.admin? || current_user.super_admin? || current_user.id.to_s == user_id.to_s
          return render json: { error: 'Access denied' }, status: :forbidden
        end

        # Withdraw consent first
        GDPRService.instance.withdraw_consent(user_id, processing_purpose)
        
        # Log the objection
        AuditLog.create!(
          restaurant_id: current_user.restaurant_id,
          user_id: current_user.id,
          action: 'data_processing_objected',
          auditable_type: 'User',
          auditable_id: user_id,
          changes: { processing_purpose: processing_purpose, reason: reason },
          metadata: { gdpr_compliance: true, objected_at: Time.current.iso8601 }
        )

        render json: { 
          success: true, 
          message: 'Objection to data processing recorded successfully',
          processing_purpose: processing_purpose,
          status: 'processing_stopped'
        }
      end

      private

      def set_restaurant
        @restaurant = current_restaurant
      end

      def authorize_gdpr_access!
        # All authenticated users can access GDPR endpoints
        # Specific authorization is handled in individual methods
        true
      end
    end
  end
end
