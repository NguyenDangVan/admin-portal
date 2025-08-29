class ImportTransactionsJob < ApplicationJob
  queue_as :default

  def perform(restaurant_id, source_type = 'csv', source_data = nil)
    restaurant = Restaurant.find(restaurant_id)
    import_count = 0
    errors = []

    case source_type
    when 'csv'
      import_count, errors = import_from_csv(restaurant, source_data)
    when 'api'
      import_count, errors = import_from_api(restaurant, source_data)
    when 'pos_system'
      import_count, errors = import_from_pos_system(restaurant)
    else
      errors << { error: "Unsupported source type: #{source_type}" }
    end

    # Send notification about import completion
    notify_import_completion(restaurant, import_count, errors)
    
    # Return results
    {
      restaurant_id: restaurant_id,
      source_type: source_type,
      import_count: import_count,
      errors: errors,
      status: errors.empty? ? 'success' : 'completed_with_errors'
    }
  end

  private

  def import_from_csv(restaurant, file_path)
    import_count = 0
    errors = []

    begin
      CSV.foreach(file_path, headers: true) do |row|
        transaction_data = build_transaction_data(restaurant, row)
        
        transaction = restaurant.transactions.build(transaction_data)
        
        if transaction.save
          import_count += 1
          log_transaction_import(restaurant, transaction, 'csv_import')
        else
          errors << {
            row: row.to_h,
            errors: transaction.errors.full_messages
          }
        end
      end

      # Clean up temporary file
      File.delete(file_path) if File.exist?(file_path)
      
    rescue => e
      errors << { error: e.message, backtrace: e.backtrace.first(5) }
    end

    [import_count, errors]
  end

  def import_from_api(restaurant, api_config)
    import_count = 0
    errors = []

    begin
      # Mock API call to external system
      response = HTTParty.get(api_config[:endpoint], {
        headers: api_config[:headers],
        query: api_config[:query_params]
      })

      if response.success?
        transactions_data = JSON.parse(response.body)
        
        transactions_data.each do |transaction_data|
          transaction = build_transaction_from_api(restaurant, transaction_data)
          
          if transaction.save
            import_count += 1
            log_transaction_import(restaurant, transaction, 'api_import')
          else
            errors << {
              data: transaction_data,
              errors: transaction.errors.full_messages
            }
          end
        end
      else
        errors << { error: "API request failed: #{response.code} - #{response.message}" }
      end
      
    rescue => e
      errors << { error: e.message, backtrace: e.backtrace.first(5) }
    end

    [import_count, errors]
  end

  def import_from_pos_system(restaurant)
    import_count = 0
    errors = []

    begin
      # Mock POS system integration
      # In a real application, this would connect to the actual POS system
      pos_transactions = mock_pos_system_data(restaurant)
      
      pos_transactions.each do |pos_data|
        transaction = build_transaction_from_pos(restaurant, pos_data)
        
        if transaction.save
          import_count += 1
          log_transaction_import(restaurant, transaction, 'pos_import')
        else
          errors << {
            data: pos_data,
            errors: transaction.errors.full_messages
          }
        end
      end
      
    rescue => e
      errors << { error: e.message, backtrace: e.backtrace.first(5) }
    end

    [import_count, errors]
  end

  def build_transaction_data(restaurant, row)
    {
      restaurant_id: restaurant.id,
      employee_id: find_or_create_employee(restaurant, row),
      transaction_id: row['transaction_id'] || generate_transaction_id(restaurant),
      amount: row['amount']&.to_f || 0.0,
      payment_method: map_payment_method(row['payment_method']),
      status: map_transaction_status(row['status']),
      transaction_time: parse_datetime(row['transaction_time']) || Time.current,
      items: parse_items(row['items']),
      notes: row['notes']
    }
  end

  def build_transaction_from_api(restaurant, api_data)
    {
      restaurant_id: restaurant.id,
      employee_id: find_or_create_employee(restaurant, api_data),
      transaction_id: api_data['external_id'] || generate_transaction_id(restaurant),
      amount: api_data['total_amount']&.to_f || 0.0,
      payment_method: map_payment_method(api_data['payment_type']),
      status: map_transaction_status(api_data['status']),
      transaction_time: parse_datetime(api_data['timestamp']) || Time.current,
      items: parse_items_from_api(api_data['line_items']),
      notes: api_data['notes']
    }
  end

  def build_transaction_from_pos(restaurant, pos_data)
    {
      restaurant_id: restaurant.id,
      employee_id: find_or_create_employee(restaurant, pos_data),
      transaction_id: pos_data['receipt_number'] || generate_transaction_id(restaurant),
      amount: pos_data['total']&.to_f || 0.0,
      payment_method: map_payment_method(pos_data['payment_method']),
      status: map_transaction_status(pos_data['status']),
      transaction_time: parse_datetime(pos_data['date_time']) || Time.current,
      items: parse_items_from_pos(pos_data['items']),
      notes: pos_data['customer_notes']
    }
  end

  def find_or_create_employee(restaurant, data)
    employee_id = data['employee_id'] || data['cashier_id'] || data['server_id']
    return nil unless employee_id

    employee = restaurant.employees.find_by(employee_id: employee_id)
    return employee.id if employee

    # Create placeholder employee if not found
    new_employee = restaurant.employees.create!(
      employee_id: employee_id,
      first_name: data['employee_name']&.split(' ')&.first || 'Unknown',
      last_name: data['employee_name']&.split(' ')&.last || 'Employee',
      position: 'cashier',
      hire_date: Date.current,
      active: true
    )

    new_employee.id
  end

  def generate_transaction_id(restaurant)
    last_transaction = restaurant.transactions.order(:transaction_id).last
    if last_transaction&.transaction_id
      last_number = last_transaction.transaction_id.match(/\d+/)[0].to_i
      "TXN#{sprintf('%06d', last_number + 1)}"
    else
      "TXN000001"
    end
  end

  def map_payment_method(payment_string)
    return 'cash' unless payment_string
    
    payment_mapping = {
      'cash' => 'cash',
      'credit' => 'credit_card',
      'credit_card' => 'credit_card',
      'debit' => 'debit_card',
      'debit_card' => 'debit_card',
      'mobile' => 'mobile_payment',
      'mobile_payment' => 'mobile_payment',
      'gift' => 'gift_card',
      'gift_card' => 'gift_card',
      'check' => 'check'
    }

    payment_mapping[payment_string.downcase] || 'cash'
  end

  def map_transaction_status(status_string)
    return 'completed' unless status_string
    
    status_mapping = {
      'completed' => 'completed',
      'complete' => 'completed',
      'success' => 'completed',
      'pending' => 'pending',
      'failed' => 'failed',
      'error' => 'failed',
      'refunded' => 'refunded',
      'cancelled' => 'cancelled',
      'cancel' => 'cancelled'
    }

    status_mapping[status_string.downcase] || 'completed'
  end

  def parse_datetime(datetime_string)
    return nil unless datetime_string
    
    # Try different datetime formats
    formats = [
      '%Y-%m-%d %H:%M:%S',
      '%Y-%m-%d %H:%M',
      '%Y-%m-%d',
      '%m/%d/%Y %H:%M:%S',
      '%m/%d/%Y %H:%M',
      '%m/%d/%Y',
      '%d/%m/%Y %H:%M:%S',
      '%d/%m/%Y %H:%M',
      '%d/%m/%Y'
    ]
    
    formats.each do |format|
      begin
        return DateTime.strptime(datetime_string, format)
      rescue ArgumentError
        next
      end
    end
    
    nil
  end

  def parse_items(items_string)
    return [] unless items_string
    
    begin
      if items_string.is_a?(String)
        JSON.parse(items_string)
      else
        items_string
      end
    rescue JSON::ParserError
      # Fallback to simple parsing
      items_string.split(',').map do |item|
        { name: item.strip, quantity: 1, price: 0.0 }
      end
    end
  end

  def parse_items_from_api(line_items)
    return [] unless line_items
    
    line_items.map do |item|
      {
        name: item['name'] || item['description'] || 'Unknown Item',
        quantity: item['quantity']&.to_i || 1,
        price: item['unit_price']&.to_f || 0.0
      }
    end
  end

  def parse_items_from_pos(pos_items)
    return [] unless pos_items
    
    pos_items.map do |item|
      {
        name: item['name'] || item['description'] || 'Unknown Item',
        quantity: item['qty']&.to_i || item['quantity']&.to_i || 1,
        price: item['price']&.to_f || item['unit_price']&.to_f || 0.0
      }
    end
  end

  def mock_pos_system_data(restaurant)
    # Mock data for demonstration
    [
      {
        'receipt_number' => "POS#{Time.current.to_i}",
        'total' => 25.99,
        'payment_method' => 'credit_card',
        'status' => 'completed',
        'date_time' => Time.current.strftime('%Y-%m-%d %H:%M:%S'),
        'items' => [
          { 'name' => 'Burger Combo', 'qty' => 1, 'price' => 15.99 },
          { 'name' => 'French Fries', 'qty' => 1, 'price' => 4.99 },
          { 'name' => 'Soft Drink', 'qty' => 1, 'price' => 5.01 }
        ],
        'employee_id' => 'EMP001',
        'customer_notes' => 'Extra cheese on burger'
      }
    ]
  end

  def log_transaction_import(restaurant, transaction, source)
    AuditLog.create!(
      restaurant_id: restaurant.id,
      action: 'transaction_imported',
      auditable_type: 'Transaction',
      auditable_id: transaction.id,
      changes: {
        transaction_id: transaction.transaction_id,
        amount: transaction.amount,
        source: source
      },
      metadata: { source: source, import_job: true }
    )
  end

  def notify_import_completion(restaurant, import_count, errors)
    Rails.logger.info "Transaction import completed for #{restaurant.name}: #{import_count} imported, #{errors.count} errors"
    
    # You could also use ActionCable to send real-time notifications
    # ActionCable.server.broadcast "restaurant_#{restaurant.id}", {
    #   type: 'transaction_import_completed',
    #   message: "Transaction import completed: #{import_count} imported",
    #   errors: errors.count
    # }
  end
end
