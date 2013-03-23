source 'https://rubygems.org'
ruby '2.0.0'

gem 'dalli', '~> 2.6.2'
gem 'jquery-rails', '~> 2.2.1'
gem 'kaminari', '~> 0.14.0'
gem 'mongoid', '~> 3.1.2'
gem 'newrelic_rpm', '~> 3.6.0'
gem 'rails', '3.2.13'
gem 'text', '~> 1.2.0'
gem 'unicorn', '~> 4.6.2', platforms: :ruby

group :assets do
  gem 'compass-rails', '~> 1.0.0'
  gem 'sass-rails', '~> 3.2.3'
  gem 'uglifier', '~> 1.3.0'
end

group :development do
  gem 'foreman', '~> 0.60'
  gem 'ruby-prof', '~> 0.12.2', platforms: :ruby
end

group :development, :test do
  gem 'coveralls', '~> 0.6.3', require: false
  gem 'rspec-rails', '~> 2.12.0'
end

group :production do
  gem 'airbrake', '~> 3.1.0'
end

group :test do
  gem 'mocha', '~> 0.13.0', require: 'mocha/api'
end
