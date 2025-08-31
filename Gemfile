source "https://rubygems.org"

ruby "3.2.2"

# Core Rails gems
gem "rails", "~> 7.1.0"
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "bootsnap", require: false

# API & Authentication
gem "jwt"
gem "bcrypt", "~> 3.1.7"
gem "rack-cors"

# Background Jobs & Caching
gem "sidekiq"
gem "redis", "~> 5.0"
gem "connection_pool"

# Authorization & Security
gem "pundit"
gem "audited", "~> 5.0"

# API & Data Processing
gem "graphql"
gem "jbuilder"
gem "csv"
gem "httparty"

# Development & Testing
group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "annotate"
  gem "bullet"
end

group :test do
  gem "vcr"
  gem "webmock"
end

