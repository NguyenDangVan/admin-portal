# 🍕 Restaurant Analytics Portal

A comprehensive, restaurant analytics platform built with Rails 7, PostgreSQL, Redis, and Sidekiq. Features include employee management, transaction tracking, discount management, and comprehensive reporting with GDPR compliance.

## 🚀 Features

### Core Functionality
- **Architecture**: Complete data isolation between restaurants using PostgreSQL RLS
- **User Management**: Role-based access control (Staff, Manager, Admin, Super Admin)
- **Employee Management**: Track employees, positions, and performance metrics
- **Transaction Tracking**: Comprehensive sales data with payment methods and status tracking
- **Discount Management**: Flexible discount system with various types and validation
- **Audit Logging**: Complete audit trail for GDPR compliance and security

### Technical Features
- **Rails 7 API**: Modern, fast API-only Rails application
- **PostgreSQL with RLS**: Row-level security for multi-tenant data isolation
- **Redis Caching**: High-performance caching for reports and analytics
- **Sidekiq**: Background job processing for data imports and reports
- **GraphQL API**: Alternative to REST with flexible querying
- **Docker Support**: Complete containerization for easy deployment
- **CI/CD Pipeline**: GitHub Actions with automated testing and deployment

## 🛠 Tech Stack

- **Backend**: Rails 7.0.8, Ruby 3.1.2
- **Database**: PostgreSQL 15 with Row-Level Security (RLS)
- **Cache**: Redis 7
- **Background Jobs**: Sidekiq
- **Authentication**: Supabase JWT integration
- **Authorization**: Pundit
- **API**: REST + GraphQL
- **Containerization**: Docker + Docker Compose
- **CI/CD**: GitHub Actions
- **Testing**: RSpec, FactoryBot, Faker

## 📋 Prerequisites

- Docker and Docker Compose
- Ruby 3.1.2
- PostgreSQL 15
- Redis 7
- Node.js (for some Rails features)

## 🚀 Quick Start

### Docker Compose setup

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd admin-portal
   ```

2. **Start all services**
   ```bash
   docker-compose up -d
   ```

3. **Setup database**
   ```bash
   docker-compose exec api rails db:create db:migrate db:seed
   ```

4. **Access the application**
   - API: http://localhost:3000
   - Sidekiq Dashboard: http://localhost:3000/sidekiq


## 🔐 Multi-Tenant Security

The application uses PostgreSQL Row-Level Security (RLS) to ensure complete data isolation between restaurants:

```sql
-- Example RLS policy for employees table
CREATE POLICY restaurant_isolation ON employees
USING (restaurant_id = current_setting('app.current_restaurant')::uuid);
```

Each request sets the current restaurant context based on the authenticated user's permissions.


## 🧪 Testing

Run the test suite:

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/restaurant_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec
```

## 🔍 Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Run Brakeman security check
bundle exec brakeman
```

## 🐳 Docker Commands

```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# View logs
docker-compose logs -f api

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up -d --build
```
## 🔒 Security Features

- **JWT Authentication**: Secure token-based authentication
- **Role-Based Access Control**: Granular permissions based on user roles
- **Audit Logging**: Complete audit trail for all data changes
- **GDPR Compliance**: Data anonymization and export capabilities
- **Input Validation**: Comprehensive validation and sanitization
- **SQL Injection Protection**: ActiveRecord with parameterized queries

## 📚 API Documentation

### Authentication Flow
1. User authenticates with Supabase
2. Supabase returns JWT token
3. Client includes JWT in Authorization header: `Bearer <token>`
4. Rails validates JWT and sets current user context
5. RLS policies enforce data isolation

### Error Handling
All API endpoints return consistent error responses:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": {
      "email": ["is invalid"]
    }
  }
}
```

## 🚀 Deployment

### Production Deployment
1. Set environment variables for production
2. Build Docker image: `docker build -t restaurant-analytics-api .`
3. Deploy to your preferred cloud platform
4. Run database migrations: `rails db:migrate RAILS_ENV=production`

### Local Demo with ngrok
Expose your local API for external access:

```bash
# Install ngrok
brew install ngrok  # macOS
# or download from https://ngrok.com/

# Expose local API
ngrok http 3000

# Share the ngrok URL for demo purposes
# Example: https://abc123.ngrok.io
```

---

**Built with ❤️ using Rails 7, PostgreSQL, and modern DevOps practices**
