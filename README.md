# Restaurant Analytics Portal

A comprehensive multi-tenant restaurant analytics platform built with Rails 7, PostgreSQL, Redis, and modern DevOps practices.

## 🚀 Features

- **Multi-tenant Architecture** with PostgreSQL Row-Level Security (RLS)
- **Real-time Analytics** and reporting dashboard
- **Role-based Access Control** (RBAC) with Pundit
- **Advanced Caching** with Redis and intelligent invalidation
- **Background Job Processing** with Sidekiq
- **GDPR Compliance** with data privacy management
- **Performance Monitoring** and health checks
- **Docker Containerization** for easy deployment
- **CI/CD Pipeline** with GitHub Actions
- **Security Scanning** with Gitleaks and Trivy

## 🛠 Tech Stack

- **Backend**: Rails 7 API
- **Database**: PostgreSQL 15 with RLS
- **Cache**: Redis 7
- **Background Jobs**: Sidekiq
- **Authentication**: JWT + Supabase
- **Authorization**: Pundit
- **Containerization**: Docker & Docker Compose
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus + Grafana
- **Security**: Gitleaks, Brakeman, Trivy

## 📋 Prerequisites

- Docker & Docker Compose
- Ruby 3.1.2
- PostgreSQL 15
- Redis 7
- ngrok (for tunneling)

## 🚀 Quick Start

### Using Docker Compose (Recommended)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd admin-portal
   ```

2. **Setup environment**
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

3. **Start the application**
   ```bash
   docker-compose up -d
   ```

4. **Setup database**
   ```bash
   docker-compose exec api bundle exec rails db:create db:migrate db:seed
   ```

5. **Access the application**
   - API: http://localhost:3000
   - Sidekiq Dashboard: http://localhost:3001
   - Adminer (Database): http://localhost:8080
   - Redis Commander: http://localhost:8081
   - ngrok Dashboard: http://localhost:4040

### Local Development

1. **Install dependencies**
   ```bash
   bundle install
   npm install
   ```

2. **Setup database**
   ```bash
   rails db:create db:migrate db:seed
   ```

3. **Start services**
   ```bash
   rails server
   sidekiq
   redis-server
   ```

## 🔧 Configuration

### Environment Variables

Create a `.env` file based on `env.example`:

```bash
# Database
DATABASE_URL=postgresql://postgres:password@localhost:5432/restaurant_analytics_development
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password

# Redis
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=your_redis_password

# Application
SECRET_KEY_BASE=your_secret_key_base
JWT_SECRET_KEY=your_jwt_secret

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key

# CORS
ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com

# ngrok
NGROK_AUTH_TOKEN=your_ngrok_auth_token
NGROK_SUBDOMAIN=your_subdomain

# Docker
DOCKER_USERNAME=your_docker_username
DOCKER_PASSWORD=your_docker_password
```

### ngrok Configuration

1. **Get ngrok auth token** from [ngrok dashboard](https://dashboard.ngrok.com/)
2. **Update `.env`** with your token and subdomain
3. **Access via ngrok**:
   - API: `https://your-subdomain.ngrok.io`
   - Sidekiq: `https://your-subdomain-sidekiq.ngrok.io`

## 🚀 Deployment

### Staging Deployment

```bash
./scripts/deploy.sh staging
```

### Production Deployment

```bash
./scripts/deploy.sh production v1.2.3
```

### Docker Deployment

```bash
# Build and push image
docker build -t your-registry/restaurant-analytics-portal:latest .
docker push your-registry/restaurant-analytics-portal:latest

# Deploy with docker-compose
docker-compose -f docker-compose.production.yml up -d
```

## 🔒 Security Features

### Multi-tenant Security
- **PostgreSQL RLS** for complete data isolation
- **UUID-based primary keys** for security
- **Role-based access control** with Pundit policies

### GDPR Compliance
- **Data export** and portability
- **Right to be forgotten** with anonymization
- **Consent management** and withdrawal
- **Audit logging** for compliance

### Security Scanning
- **Gitleaks** for secret detection
- **Brakeman** for security vulnerabilities
- **Trivy** for container vulnerabilities
- **Bundle audit** for gem security

## 📊 Monitoring & Performance

### Health Checks
- **System health monitoring** every 15 minutes
- **Cache health checks** every 10 minutes
- **Database connection monitoring**
- **Sidekiq job monitoring**

### Performance Metrics
- **API response times** and throughput
- **Database query performance**
- **Cache hit rates** and efficiency
- **Background job performance**

### Monitoring Tools
- **Prometheus** for metrics collection
- **Grafana** for visualization
- **Redis Commander** for cache management
- **Adminer** for database management

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

1. **Test Stage**
   - Ruby version check
   - Gem installation
   - Database setup
   - RSpec test suite
   - Code coverage reporting

2. **Security Stage**
   - RuboCop linting
   - Brakeman security scan
   - Bundle audit
   - Gitleaks secret detection
   - Trivy vulnerability scan

3. **Build Stage**
   - Docker image build
   - Image tagging and metadata
   - Push to registry

4. **Deploy Stage**
   - Preview deployment for PRs
   - Production deployment for releases
   - Health checks and verification

5. **Performance Stage**
   - Performance testing
   - Metrics generation
   - Documentation generation

### Automated Deployments

- **Pull Requests**: Automatic preview deployment
- **Main Branch**: Automatic staging deployment
- **Releases**: Manual production deployment
- **Rollbacks**: Automatic rollback on failure

## 📚 API Documentation

### Core Endpoints

- `GET /api/v1/restaurants` - List restaurants
- `GET /api/v1/restaurants/:id/dashboard` - Restaurant dashboard
- `GET /api/v1/employees` - List employees
- `GET /api/v1/transactions` - List transactions
- `GET /api/v1/reports/sales_analytics` - Sales analytics

### GDPR Endpoints

- `GET /api/v1/gdpr/export_data` - Export user data
- `POST /api/v1/gdpr/anonymize_data` - Anonymize user data
- `GET /api/v1/gdpr/compliance_report` - GDPR compliance report

### Monitoring Endpoints

- `GET /api/v1/monitoring/performance_report` - Performance metrics
- `GET /api/v1/monitoring/system_health` - System health status
- `GET /api/v1/monitoring/cache_stats` - Cache statistics

## 🧪 Testing

### Test Suite

```bash
# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/models/
bundle exec rspec spec/controllers/

# Run with coverage
bundle exec rspec --coverage

# Run performance tests
bundle exec rspec spec/performance/
```

### Test Coverage

- **Model tests**: 95%+ coverage
- **Controller tests**: 90%+ coverage
- **Service tests**: 85%+ coverage
- **Integration tests**: 80%+ coverage

## 🔧 Development

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -a

# Run Brakeman security scan
bundle exec brakeman

# Run bundle audit
bundle audit check --update
```

### Database Management

```bash
# Create database
rails db:create

# Run migrations
rails db:migrate

# Seed data
rails db:seed

# Reset database
rails db:reset

# Generate migration
rails generate migration AddFieldToTable
```

### Background Jobs

```bash
# Start Sidekiq
bundle exec sidekiq

# Monitor jobs
bundle exec sidekiqmon

# Enqueue test job
rails runner "ImportEmployeesJob.perform_later"
```

## 🐳 Docker Commands

### Development

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f api
docker-compose logs -f sidekiq

# Execute commands
docker-compose exec api bundle exec rails console
docker-compose exec db psql -U postgres

# Stop services
docker-compose down
```

### Production

```bash
# Start production services
docker-compose -f docker-compose.production.yml up -d

# View production logs
docker-compose -f docker-compose.production.yml logs -f

# Scale services
docker-compose -f docker-compose.production.yml up -d --scale api=3
```

## 📈 Performance Optimization

### Caching Strategy
- **Redis caching** with intelligent TTL
- **Cache tags** for automatic invalidation
- **Conditional caching** for dynamic data
- **Batch operations** for efficiency

### Database Optimization
- **Connection pooling** configuration
- **Query optimization** with indexes
- **Background job processing** for heavy operations
- **Data archiving** for old records

### Background Jobs
- **Priority queues** for critical operations
- **Retry mechanisms** with exponential backoff
- **Job monitoring** and alerting
- **Scheduled jobs** for maintenance tasks

## 🔍 Troubleshooting

### Common Issues

1. **Database connection errors**
   - Check PostgreSQL service status
   - Verify connection credentials
   - Check network connectivity

2. **Redis connection issues**
   - Verify Redis service status
   - Check authentication settings
   - Monitor memory usage

3. **Sidekiq job failures**
   - Check job logs
   - Verify Redis connectivity
   - Monitor queue sizes

4. **Performance issues**
   - Check cache hit rates
   - Monitor database query performance
   - Review background job processing

### Debug Commands

```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs -f [service_name]

# Check database connections
docker-compose exec db psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Monitor Redis
docker-compose exec redis redis-cli monitor

# Check Sidekiq queues
docker-compose exec api bundle exec rails runner "puts Sidekiq::Stats.new.queues"
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests for new functionality**
5. **Ensure all tests pass**
6. **Submit a pull request**

### Development Guidelines

- **Follow Ruby style guide** (RuboCop enforced)
- **Write comprehensive tests** for new features
- **Update documentation** for API changes
- **Use conventional commit messages**
- **Include security considerations** in new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/your-repo/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **Security**: [Security Policy](SECURITY.md)

## 🗺 Roadmap

### Phase 1: Foundation ✅
- [x] Rails 7 API setup
- [x] PostgreSQL with RLS
- [x] Basic models and migrations
- [x] Docker configuration

### Phase 2: Core API & Data Model ✅
- [x] API controllers and routes
- [x] Background job processing
- [x] Redis caching layer
- [x] Data import functionality

### Phase 3: Performance & Security ✅
- [x] Role-based access control
- [x] Advanced caching strategies
- [x] Performance monitoring
- [x] GDPR compliance

### Phase 4: CI/CD + Local Deploy ✅
- [x] GitHub Actions pipeline
- [x] Security scanning
- [x] Docker deployment
- [x] ngrok integration

### Future Phases
- [ ] GraphQL API
- [ ] Real-time notifications
- [ ] Advanced analytics
- [ ] Mobile app support
- [ ] Multi-language support
