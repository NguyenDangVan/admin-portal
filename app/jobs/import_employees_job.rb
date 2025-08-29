class ImportEmployeesJob < ApplicationJob
  queue_as :default

  def perform(restaurant_id, file_path)
    restaurant = Restaurant.find(restaurant_id)
    import_count = 0
    errors = []

    begin
      CSV.foreach(file_path, headers: true) do |row|
        employee_data = {
          restaurant_id: restaurant_id,
          employee_id: row['employee_id'] || generate_employee_id(restaurant),
          first_name: row['first_name'],
          last_name: row['last_name'],
          email: row['email'],
          phone: row['phone'],
          position: map_position(row['position']),
          hourly_rate: row['hourly_rate']&.to_f,
          hire_date: parse_date(row['hire_date']) || Date.current,
          active: row['active'] != 'false'
        }

        employee = restaurant.employees.build(employee_data)
        
        if employee.save
          import_count += 1
          # Log successful import
          AuditLog.create!(
            restaurant_id: restaurant_id,
            action: 'employee_imported',
            auditable_type: 'Employee',
            auditable_id: employee.id,
            changes: employee_data,
            metadata: { source: 'csv_import', file_path: file_path }
          )
        else
          errors << {
            row: row.to_h,
            errors: employee.errors.full_messages
          }
        end
      end

      # Send notification about import completion
      notify_import_completion(restaurant, import_count, errors)
      
    rescue => e
      errors << { error: e.message, backtrace: e.backtrace.first(5) }
      notify_import_error(restaurant, e.message)
    end

    # Clean up temporary file
    File.delete(file_path) if File.exist?(file_path)
    
    # Return results
    {
      restaurant_id: restaurant_id,
      import_count: import_count,
      errors: errors,
      status: errors.empty? ? 'success' : 'completed_with_errors'
    }
  end

  private

  def generate_employee_id(restaurant)
    last_employee = restaurant.employees.order(:employee_id).last
    if last_employee&.employee_id
      last_number = last_employee.employee_id.match(/\d+/)[0].to_i
      "EMP#{sprintf('%03d', last_number + 1)}"
    else
      "EMP001"
    end
  end

  def map_position(position_string)
    return 'cashier' unless position_string
    
    position_mapping = {
      'cashier' => 'cashier',
      'server' => 'server',
      'waiter' => 'server',
      'waitress' => 'server',
      'cook' => 'cook',
      'chef' => 'cook',
      'kitchen' => 'cook',
      'manager' => 'manager',
      'supervisor' => 'supervisor',
      'host' => 'host',
      'hostess' => 'host',
      'bartender' => 'bartender',
      'bar' => 'bartender'
    }

    position_mapping[position_string.downcase] || 'cashier'
  end

  def parse_date(date_string)
    return nil unless date_string
    
    # Try different date formats
    formats = ['%Y-%m-%d', '%m/%d/%Y', '%d/%m/%Y', '%Y/%m/%d']
    
    formats.each do |format|
      begin
        return Date.strptime(date_string, format)
      rescue ArgumentError
        next
      end
    end
    
    nil
  end

  def notify_import_completion(restaurant, import_count, errors)
    # In a real application, you might send an email or push notification
    Rails.logger.info "Employee import completed for #{restaurant.name}: #{import_count} imported, #{errors.count} errors"
    
    # You could also use ActionCable to send real-time notifications
    # ActionCable.server.broadcast "restaurant_#{restaurant.id}", {
    #   type: 'import_completed',
    #   message: "Employee import completed: #{import_count} imported",
    #   errors: errors.count
    # }
  end

  def notify_import_error(restaurant, error_message)
    Rails.logger.error "Employee import failed for #{restaurant.name}: #{error_message}"
    
    # Notify administrators about the failure
    # ActionCable.server.broadcast "restaurant_#{restaurant.id}", {
    #   type: 'import_failed',
    #   message: "Employee import failed: #{error_message}"
    # }
  end
end
