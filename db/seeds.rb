# Clear existing data
puts "Clearing existing data..."
Restaurant.destroy_all
User.destroy_all
Employee.destroy_all
Transaction.destroy_all
Discount.destroy_all
AuditLog.destroy_all

# Create sample restaurants
puts "Creating sample restaurants..."
restaurant1 = Restaurant.create!(
  name: "Pizza Palace",
  address: "123 Main St, Downtown",
  phone: "+1-555-0123",
  email: "info@pizzapalace.com",
  status: :active
)

restaurant2 = Restaurant.create!(
  name: "Burger Barn",
  address: "456 Oak Ave, Uptown",
  phone: "+1-555-0456",
  email: "hello@burgerbarn.com",
  status: :active
)

restaurant3 = Restaurant.create!(
  name: "Sushi Express",
  address: "789 Pine Rd, Midtown",
  phone: "+1-555-0789",
  email: "contact@sushiexpress.com",
  status: :active
)

puts "Created #{Restaurant.count} restaurants"

# Create sample users
puts "Creating sample users..."
user1 = User.create!(
  supabase_uid: "user_001",
  email: "admin@pizzapalace.com",
  first_name: "John",
  last_name: "Admin",
  role: :admin,
  restaurant: restaurant1,
  active: true
)

user2 = User.create!(
  supabase_uid: "user_002",
  email: "manager@burgerbarn.com",
  first_name: "Sarah",
  last_name: "Manager",
  role: :manager,
  restaurant: restaurant2,
  active: true
)

user3 = User.create!(
  supabase_uid: "user_003",
  email: "staff@sushiexpress.com",
  first_name: "Mike",
  last_name: "Staff",
  role: :staff,
  restaurant: restaurant3,
  active: true
)

puts "Created #{User.count} users"

# Create sample employees
puts "Creating sample employees..."
employee1 = Employee.create!(
  restaurant: restaurant1,
  employee_id: "EMP001",
  first_name: "Alice",
  last_name: "Johnson",
  email: "alice@pizzapalace.com",
  phone: "+1-555-0001",
  position: :manager,
  hourly_rate: 25.00,
  hire_date: 1.year.ago,
  active: true
)

employee2 = Employee.create!(
  restaurant: restaurant1,
  employee_id: "EMP002",
  first_name: "Bob",
  last_name: "Smith",
  email: "bob@pizzapalace.com",
  phone: "+1-555-0002",
  position: :cashier,
  hourly_rate: 18.00,
  hire_date: 6.months.ago,
  active: true
)

employee3 = Employee.create!(
  restaurant: restaurant2,
  employee_id: "EMP003",
  first_name: "Carol",
  last_name: "Davis",
  email: "carol@burgerbarn.com",
  phone: "+1-555-0003",
  position: :cook,
  hourly_rate: 22.00,
  hire_date: 8.months.ago,
  active: true
)

puts "Created #{Employee.count} employees"

# Create sample transactions
puts "Creating sample transactions..."
transaction1 = Transaction.create!(
  restaurant: restaurant1,
  employee: employee1,
  transaction_id: "TXN001",
  amount: 45.99,
  payment_method: :credit_card,
  status: :completed,
  transaction_time: 1.day.ago,
  items: [
    { name: "Large Pepperoni Pizza", quantity: 1, price: 24.99 },
    { name: "Garlic Bread", quantity: 1, price: 8.99 },
    { name: "Soft Drink", quantity: 2, price: 6.00 }
  ],
  notes: "Customer requested extra cheese"
)

transaction2 = Transaction.create!(
  restaurant: restaurant1,
  employee: employee2,
  transaction_id: "TXN002",
  amount: 32.50,
  payment_method: :cash,
  status: :completed,
  transaction_time: 2.days.ago,
  items: [
    { name: "Medium Margherita Pizza", quantity: 1, price: 18.99 },
    { name: "Caesar Salad", quantity: 1, price: 13.51 }
  ]
)

transaction3 = Transaction.create!(
  restaurant: restaurant2,
  employee: employee3,
  transaction_id: "TXN003",
  amount: 28.75,
  payment_method: :debit_card,
  status: :completed,
  transaction_time: 3.days.ago,
  items: [
    { name: "Classic Burger", quantity: 1, price: 12.99 },
    { name: "French Fries", quantity: 1, price: 4.99 },
    { name: "Milkshake", quantity: 1, price: 6.99 },
    { name: "Onion Rings", quantity: 1, price: 3.78 }
  ]
)

puts "Created #{Transaction.count} transactions"

# Create sample discounts
puts "Creating sample discounts..."
discount1 = Discount.create!(
  restaurant: restaurant1,
  name: "Student Discount",
  description: "20% off for students with valid ID",
  discount_type: :percentage,
  value: 20.0,
  is_percentage: true,
  start_date: Date.current,
  end_date: 1.year.from_now,
  active: true,
  conditions: { requires_student_id: true, min_order: 15.0 }
)

discount2 = Discount.create!(
  restaurant: restaurant2,
  name: "Happy Hour",
  description: "$5 off orders over $25 during happy hour",
  discount_type: :fixed_amount,
  value: 5.0,
  is_percentage: false,
  start_date: Date.current,
  end_date: 1.year.from_now,
  active: true,
  conditions: { time_restriction: "4:00 PM - 7:00 PM", min_order: 25.0 }
)

puts "Created #{Discount.count} discounts"

# Create sample audit logs
puts "Creating sample audit logs..."
AuditLog.create!(
  restaurant: restaurant1,
  user: user1,
  action: "restaurant_created",
  auditable_type: "Restaurant",
  auditable_id: restaurant1.id,
  changes: { name: restaurant1.name, status: restaurant1.status },
  metadata: { ip_address: "127.0.0.1", user_agent: "Seed Script" }
)

AuditLog.create!(
  restaurant: restaurant1,
  user: user1,
  action: "employee_created",
  auditable_type: "Employee",
  auditable_id: employee1.id,
  changes: { first_name: employee1.first_name, position: employee1.position },
  metadata: { ip_address: "127.0.0.1", user_agent: "Seed Script" }
)

puts "Created #{AuditLog.count} audit logs"

puts "\n🎉 Seed data created successfully!"
puts "📊 Summary:"
puts "  - Restaurants: #{Restaurant.count}"
puts "  - Users: #{User.count}"
puts "  - Employees: #{Employee.count}"
puts "  - Transactions: #{Transaction.count}"
puts "  - Discounts: #{Discount.count}"
puts "  - Audit Logs: #{AuditLog.count}"

puts "\n🔑 Sample login credentials:"
puts "  - Admin: admin@pizzapalace.com (Admin role)"
puts "  - Manager: manager@burgerbarn.com (Manager role)"
puts "  - Staff: staff@sushiexpress.com (Staff role)"

puts "\n🚀 You can now start the application with:"
puts "  docker-compose up -d"
puts "  # or"
puts "  rails server"
