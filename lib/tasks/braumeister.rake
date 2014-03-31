# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2014, Sebastian Staudt

if defined? ::NewRelic
  def task_with_tracing(*options)
    caller_method = options.first
    caller_method = caller_method.keys.first if caller_method.is_a? Hash

    task *options do
      include NewRelic::Agent::Instrumentation::ControllerInstrumentation

      perform_action_with_newrelic_trace name: caller_method.to_s, category: :task, force: true do
        yield
      end
    end
  end
else
  class << self
    alias_method :task_with_tracing, :task
  end
end

if defined?(Airbrake) && !Airbrake.configuration.api_key.nil?
  def airbrake_rescued(&action)
    begin
      action.call
    rescue
      Airbrake.notify $!
    end
  end
else
  def airbrake_rescued(&action)
    action.call
  end
end

namespace :braumeister do

  Rails.logger = Logger.new STDOUT

  task :select_repos, [:repo] => :environment do |t, args|
    Mongoid.unit_of_work disable: :all do
      @repos = args[:repo].nil? ? Repository.all : Repository.where(name: args[:repo])
    end
  end

  desc 'Completely regenerates one or all repositories and their formulae'
  task_with_tracing :regenerate, [:repo] => :select_repos do
    Mongoid.unit_of_work disable: :all do
      @repos.each &:regenerate!
    end
  end

  desc 'Regenerates the history of one or all repositories'
  task_with_tracing :regenerate_history, [:repo] => :select_repos do
    Mongoid.unit_of_work disable: :all do
      @repos.each &:generate_history!
    end
  end

  desc 'Pulls the latest changes from one or all repositories'
  task_with_tracing :update, [:repo] => :select_repos do
    Mongoid.unit_of_work disable: :all do
      @repos.each do |repo|
        airbrake_rescued { repo.refresh }
      end
    end
  end

end
