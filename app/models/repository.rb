# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2013, Sebastian Staudt

class Repository

  include Mongoid::Document
  include Mongoid::Timestamps::Updated

  ALIAS_REGEX = /^(?:Library\/)?Aliases\/(.+?)$/
  MAIN        = 'mxcl/homebrew'

  field :_id, type: String, default: ->{ name }
  field :date, type: Time
  field :full, type: Boolean, default: false
  field :name, type: String
  field :sha, type: String

  has_many :authors
  has_many :formulae, dependent: :destroy
  has_many :revisions, dependent: :destroy

  def self.main
    find MAIN
  end

  def clone_or_pull
    Repository.main.clone_or_pull unless full?

    if File.exists? path
      Rails.logger.info "Pulling changes from #{name} into #{path}"
      git 'fetch --force --quiet origin master'
      diff = git 'diff --shortstat HEAD FETCH_HEAD'
      unless diff.empty?
        git "--work-tree #{path} reset --hard --quiet FETCH_HEAD"
      end
    else
      Rails.logger.info "Cloning #{name} into #{path}"
      git "clone --quiet #{url} #{path}"
    end
  end

  def generate_history!
    update_status

    Rails.logger.info "Resetting history of #{name}"
    self.formulae.each { |f| f.revisions.nullify }
    self.revisions.destroy
    self.revisions.clear
    self.authors.destroy
    self.authors.clear

    generate_history
  end

  def generate_history(last_sha = nil)
    ref = last_sha.nil? ? 'HEAD' : "#{last_sha}..HEAD"

    Rails.logger.info "Regenerating history for #{ref}..."

    log_cmd = "log --format=format:'%H%x00%ct%x00%aE%x00%aN%x00%s' --name-status --no-merges --reverse #{ref}"
    log_cmd << " -- 'Formula' 'Library/Formula'" if full?
    log = git log_cmd

    commits = log.split(/\n\n/)
    commit_progress = 0
    commit_count = commits.size
    while !commits.empty?
      commit_batch = commits.shift 100
      commit_batch.each do |commit|
        commit = commit.lines.to_a
        info, formulae = commit.shift.strip.split("\x00"), commit
        rev = self.revisions.build sha: info[0]
        rev.author = self.authors.find_or_initialize_by email: info[2]
        rev.author.name = info[3]
        rev.author.save!
        rev.date = info[1].to_i
        rev.subject = info[4]
        formulae.each do |formula|
          status, name = formula.split
          name.match(formula_regex)
          next unless full? || $~
          name = File.basename $~[1], '.rb'
          formula = self.formulae.where(name: name).first
          next if formula.nil?
          formula.revisions << rev
          formula.date = rev.date if formula.date.nil? || rev.date > formula.date
          formula.save!
          if status == 'A'
            rev.added_formulae << formula
          elsif status == 'M'
            rev.updated_formulae << formula
          elsif status == 'D'
            rev.removed_formulae << formula
          end
        end
        rev.save!
        self.revisions << rev
      end

      save!

      commit_progress += commit_batch.size
      Rails.logger.debug "Analyzed #{commit_progress} of #{commit_count} revisions."
    end
  end

  def git(command)
    command = "git --git-dir #{path}/.git #{command}"
    Rails.logger.debug "Executing `#{command}`"
    output = `#{command}`.strip

    raise "Execution of `#{command}` failed." unless $?.success?

    output
  end

  def main?
    name == MAIN
  end

  def path
    "#{Braumeister::Application.tmp_path}/repos/#{name}"
  end

  def refresh
    formulae, aliases, last_sha = update_status

    if formulae.size == 0 && aliases.size == 0
      Rails.logger.info 'No formulae changed.'
      updated_at_will_change!
      save!
      return
    end

    updated_formulae = []
    formulae.each do |type, fpath|
      updated_formulae << fpath.match(formula_regex)[1] unless type == 'D'
    end
    formulae_info = formulae_info updated_formulae
    updated_formulae = nil

    added = modified = removed = 0
    formulae.each do |type, fpath|
      path, name = File.split fpath.match(formula_regex)[1]
      name = File.basename name, '.rb'
      formula = self.formulae.find_or_initialize_by name: name
      formula.path = (full? || path == '.' ? nil : path)
      if type == 'D'
        removed += 1
        formula.removed = true
        Rails.logger.debug "Removed formula #{formula.name}."
      else
        if type == 'A'
          added += 1
          Rails.logger.debug "Added formula #{formula.name}."
        else
          modified += 1
          Rails.logger.debug "Updated formula #{formula.name}."
        end
        formula.deps = []
        formula_info = formulae_info.delete formula.name
        next if formula_info.nil?
        formula_info[:deps].each do |dep|
          dep_formula = self.formulae.where(name: dep).first
          if dep_formula.nil?
            dep_formula = Repository.main.formulae.where(name: dep).first
          end
          formula.deps << dep_formula unless dep_formula.nil?
        end
        formula.homepage = formula_info[:homepage]
        formula.keg_only = formula_info[:keg_only]
        formula.removed  = false
        formula.version  = formula_info[:version]
      end
      formula.save!
    end

    aliases.each do |type, apath|
      name = apath.match(ALIAS_REGEX)[1]
      formula = nil
      if type == 'D'
        formula = self.formulae.where(aliases: name).first
        next if formula.nil?
        formula.aliases.delete name
      else
        alias_path = File.join path, apath
        next unless FileTest.symlink? alias_path
        formula_name  = File.basename File.readlink(alias_path), '.rb'
        formula = self.formulae.where(name: formula_name).first
        next if formula.nil?
        formula.aliases ||= []
        formula.aliases << name
      end
      formula.save!
    end

    generate_history last_sha

    Rails.logger.info "#{added} formulae added, #{modified} formulae modified, #{removed} formulae removed."
  end

  def to_param
    name
  end

  def update_status
    clone_or_pull

    last_sha = sha
    log = git('log -1 --format=format:"%H %ct" HEAD').split
    self.sha = log[0]
    self.date = Time.at log[1].to_i

    if last_sha.nil?
      if full?
        formulae = git 'ls-tree --name-only HEAD Library/Formula/'
        formulae = formulae.lines.map { |file| ['A', file.strip] }

        aliases = git 'ls-tree --name-only HEAD Library/Aliases/'
        aliases = aliases.lines.map { |file| ['A', file.strip] }
      else
        formulae = git 'ls-tree --name-only -r HEAD'
        formulae = formulae.lines.select { |file| file.match formula_regex }.
          map { |file| ['A', file.strip] }

        aliases = []
      end

      Rails.logger.info "Checked out #{sha} in #{path}"
    else
      diff = git "diff --name-status #{last_sha}..HEAD"
      diff = diff.lines.map { |file| file.split }

      formulae = diff.select { |file| file[1] =~ formula_regex }
      aliases = full? ? diff.select { |file| file[1] =~ ALIAS_REGEX } : []

      Rails.logger.info "Updated #{name} from #{last_sha} to #{sha}:"
    end

    unless full?
      formulae_path = File.join Repository.main.path, 'Library', 'Formula'
      Dir.glob File.join(path, '*.rb') do |formula|
        `ln -s #{formula} #{formulae_path} 2>/dev/null`
      end
    end

    return formulae, aliases, last_sha
  end

  def url
    "git://github.com/#{name}.git"
  end

  private

  def formulae_info(formulae)
    base_repo = full? ? self : Repository.main

    pipe_read, pipe_write = IO.pipe

    pid = fork do
      begin
        pipe_read.close

        require 'sandbox_backtick'
        require 'sandbox_io_popen'

        $homebrew_path = base_repo.path
        $LOAD_PATH.unshift $homebrew_path
        $LOAD_PATH.unshift File.join($homebrew_path, 'Library', 'Homebrew')
        ENV['HOMEBREW_BREW_FILE'] = File.join $homebrew_path, 'bin', 'brew'

        Object.send(:remove_const, :Formula) if Object.const_defined? :Formula

        require 'Library/Homebrew/global'
        require 'Library/Homebrew/formula'

        require 'sandbox_macos'

        formulae_info = {}
        formulae.each do |name|
          begin
            formula_name = File.basename name, '.rb'
            formula_class = Formula.class_s(formula_name).to_sym
            if Object.const_defined? formula_class
              Object.send :remove_const, formula_class
            end

            name = File.join path, name unless full? || name.start_with?(path)
            formula = Formula.factory name
            formulae_info[formula.name] = {
              deps: formula.deps.map(&:to_s),
              homepage: formula.homepage,
              keg_only: formula.keg_only? != false,
              version: formula.version.to_s
            }
          rescue FormulaUnavailableError, NoMethodError, RuntimeError,
                 SyntaxError
            error_msg = "Formula '#{name}' could not be imported because of an error."
            Rails.logger.warn error_msg
            if defined?(Airbrake) && !Airbrake.configuration.api_key.nil?
              Airbrake.notify $!, { error_message: error_msg }
            end
          end
        end

        Marshal.dump formulae_info, pipe_write
      rescue
        Marshal.dump $!, pipe_write
      end

      pipe_write.flush
      pipe_write.close

      exit!
    end

    pipe_write.close
    formulae_info = Marshal.load pipe_read
    Process.wait pid
    pipe_read.close
    if formulae_info.is_a? StandardError
      raise formulae_info, formulae_info.message, formulae_info.backtrace
    end

    formulae_info
  end

  def formula_regex
    full? ? /^(?:Library\/)?Formula\/(.+?)\.rb$/ : /^(.+?\.rb)$/
  end

end
