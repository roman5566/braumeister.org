ruby '1.9.3'
source :rubygems

gem 'bson_ext', '~> 1.7.0', platforms: :ruby
gem 'dalli', '~> 2.2.0'
gem 'jquery-rails', '~> 2.1.1'
gem 'kaminari', '~> 0.14.0'
gem 'mongoid', '~> 2.5.0'
gem 'newrelic_rpm', '~> 3.5.0'
gem 'rails', '3.2.9'
gem 'text', '~> 1.2.0'
gem 'unicorn', '~> 4.4.0', platforms: :ruby

group :assets do
  gem 'compass-rails', '~> 1.0.0'
  gem 'sass-rails', '~> 3.2.3'
  gem 'uglifier', '~> 1.3.0'
end

group 'development' do
  gem 'ruby-prof', '~> 0.11.2', platforms: :ruby
end

group :development, :test do
  gem 'rspec-rails', '~> 2.12.0'
end

group :production do
  gem 'airbrake', '~> 3.1.0'
end

group :test do
  gem 'mocha', '~> 0.12.1', require: 'mocha_standalone'
end
