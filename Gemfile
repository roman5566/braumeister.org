source 'https://rubygems.org'
ruby '2.1.0'

gem 'dalli', '~> 2.7.0'
gem 'jquery-rails', '~> 3.0.4'
gem 'kaminari', '~> 0.15.0'
gem 'mongoid', '~> 3.1.2'
gem 'newrelic_rpm', '~> 3.7.0'
gem 'rails', '3.2.16'
gem 'text', '~> 1.2.0'
gem 'unicorn', '~> 4.8.1', platforms: :ruby

group :assets do
  gem 'compass-rails', '~> 1.1.0'
  gem 'sass-rails', '~> 3.2.3'
  gem 'uglifier', '~> 2.4.0'
end

group :development do
  gem 'foreman', '~> 0.60'
end

group :development, :test do
  gem 'coveralls', '~> 0.7.0', require: false
  gem 'rspec-rails', '~> 2.14.0'
end

group :production do
  gem 'airbrake', '~> 3.1.0'
  gem 'rails_12factor', '~> 0.0.2'
end

group :test do
  gem 'mocha', '~> 0.14.0', require: 'mocha/api'
end
