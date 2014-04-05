# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2014, Sebastian Staudt

class Repository

  include Mongoid::Document
  include Mongoid::Timestamps::Updated

  ALIAS_REGEX = /^(?:Library\/)?Aliases\/(.+?)$/
  MAIN        = 'Homebrew/homebrew'

  field :_id, type: String, default: ->{ name }
  field :date, type: Time
  field :full, type: Boolean, default: false
  field :name, type: String
  field :sha, type: String

  has_many :authors, validate: false
  has_many :formulae, dependent: :destroy, validate: false
  has_many :revisions, dependent: :destroy, validate: false

  def self.main
    find MAIN
  end

  def clone_or_pull(reset = true)
    Repository.main.clone_or_pull unless full?

    if File.exists? path
      Rails.logger.info "Pulling changes from #{name} into #{path}"
      git 'fetch --force --quiet origin master'
      if reset
        diff = git 'diff --shortstat HEAD FETCH_HEAD'
        unless diff.empty?
          git "--work-tree #{path} reset --hard --quiet FETCH_HEAD"
        end
      end
    else
      Rails.logger.info "Cloning #{name} into #{path}"
      git "clone --quiet #{url} #{path}"
    end
  end

  def find_formula(name)
    git("ls-files | grep -E '(^|/)#{name}.rb'").lines.first.strip rescue nil
  end

  def generate_formula_history(formula)
    Rails.logger.info "Regenerating history for formula #{formula.name}..."

    analyze_commits "--follow -- #{formula.path}"
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

    log_cmd = ref
    log_cmd << " -- 'Formula' 'Library/Formula'" if full?

    analyze_commits log_cmd
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

  def recover_deleted_formulae
    clone_or_pull false
    reset_head

    log_cmd = "log --format=format:'%H' --diff-filter=D -M --name-only"
    log_cmd << " -- 'Formula' 'Library/Formula'" if full?

    git(log_cmd).split(/\n\n/).each do |commit|
      sha, *files = commit.lines
      sha.strip!

      formulae = files.map do |path|
        next unless path =~ formula_regex
        name = File.basename $1, '.rb'
        $1 if name != '__template' && self.formulae.where(name: name).empty?
      end.compact
      formulae.compact!

      next if formulae.empty?

      Rails.logger.debug "Trying to recover the following formulae: #{formulae.join ', '}"
      begin
        sha << '^'
        reset_head sha

        Rails.logger.debug "Trying to import missing formulae from commit #{sha}…"

        formulae_info = formulae_info formulae, true
        formulae.each do |name|
          formula_name = File.basename name, '.rb'
          formula = self.formulae.find_or_initialize_by name: formula_name
          formula_info = formulae_info.delete formula.name
          next if formula_info.nil?
          formula.deps = formula_info[:deps].map do |dep|
            self.formulae.where(name: dep).first ||
              Repository.main.formulae.where(name: dep).first
          end
          formula.removed  = true
          formula.update_metadata formula_info
          formula.save
          Rails.logger.info "Successfully recovered #{formula.name} from commit #{sha}"
        end
      rescue
        Rails.logger.debug "Commit #{sha} could not be imported because of an error: #{$!.message}"
        retry unless sha =~ /\^\^\^\^\^/
      end
    end

    reset_head
  end

  def refresh
    formulae, aliases, last_sha = update_status

    if formulae.empty? && aliases.empty?
      Rails.logger.info 'No formulae changed.'
      touch
      save!
      return
    end

    formulae_info = formulae_info formulae.map { |type, fpath|
      fpath.match(formula_regex)[1] unless type == 'D'
    }.compact

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
        formula_info = formulae_info.delete formula.name
        next if formula_info.nil?
        formula.deps = formula_info[:deps].map do |dep|
          self.formulae.where(name: dep).first ||
            Repository.main.formulae.where(name: dep).first
        end
        formula.update_metadata formula_info
        formula.removed = false
      end
      formula.save!
    end

    aliases.each do |type, apath|
      name = apath.match(ALIAS_REGEX)[1]
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

  def regenerate!
    FileUtils.rm_rf path
    Author.where(repository_id: id).delete
    Formula.where(repository_id: id).delete
    Revision.where(repository_id: id).delete

    Formula.each do |formula|
      formula.update_attribute :dep_ids, formula.dep_ids.reject! { |i| i.starts_with? "#{id}/" }
      formula.update_attribute :revdep_ids, formula.revdep_ids.reject! { |i| i.starts_with? "#{id}/" }
    end

    authors.clear
    formulae.clear
    revisions.clear
    self.sha = nil
    save!

    refresh
    recover_deleted_formulae
  end

  def reset_head(sha = self.sha)
    git "--work-tree #{path} reset --hard --quiet #{sha}"
  end

  def to_param
    name
  end

  def update_metadata
    clone_or_pull false
    reset_head

    formulae = self.formulae.where(removed: false).map do |formula|
      formula.path || formula.name
    end

    formulae_info(formulae).each do |name, formula_info|
      formula = self.formulae.find_by name: name
      formula.update_metadata formula_info
      formula.save!
    end
  end

  def update_status
    clone_or_pull

    last_sha = sha
    log = git('log -1 --format=format:"%H %ct" HEAD').split
    self.sha = log[0]
    self.date = Time.at log[1].to_i

    return [], [], sha if sha == last_sha

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

  def analyze_commits(log_params)
    reset_head
    log_cmd = "log --format=format:'%H%x00%ct%x00%aE%x00%aN%x00%s' --name-status --no-merges #{log_params}"

    commits = git(log_cmd).split /\n\n/
    commit_progress = 0
    commit_count = commits.size
    commits.each_slice(100) do |commit_batch|
      commit_batch.each do |commit|
        info, *formulae = commit.lines
        sha, timestamp, email, name, subject = info.strip.split "\x00"
        rev = self.revisions.build sha: sha
        rev.author = self.authors.find_or_initialize_by email: email
        rev.author.name = name
        rev.author.save!
        rev.date = timestamp.to_i
        rev.subject = subject
        formulae.each do |formula|
          status, name = formula.split
          next unless name =~ formula_regex
          name = File.basename $~[1], '.rb'
          formula = self.formulae.where(name: name).first
          next if formula.nil?
          formula.revisions << rev
          formula.date = rev.date if formula.date.nil? || rev.date > formula.date
          formula.save!
          if status == 'M' || status =~ /R\d\d\d/
            rev.updated_formulae << formula
          elsif status == 'A'
            rev.added_formulae << formula
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

  def formulae_info(formulae, backward_compat = false)
    base_repo = full? ? self : Repository.main

    tmp_file = Tempfile.new 'braumeister-import'

    pid = fork do
      begin
        require 'sandbox_backtick'
        require 'sandbox_io_popen'

        $homebrew_path = base_repo.path
        $LOAD_PATH.unshift $homebrew_path
        $LOAD_PATH.unshift File.join($homebrew_path, 'Library', 'Homebrew')
        ENV['HOMEBREW_BREW_FILE'] = File.join $homebrew_path, 'bin', 'brew'

        Object.send(:remove_const, :Formula) if Object.const_defined? :Formula

        require 'backward_compat' if backward_compat

        require 'Library/Homebrew/global'
        require 'Library/Homebrew/formula'

        require 'sandbox_formulary'
        require 'sandbox_macos'
        require 'sandbox_utils'

        formulae_info = {}
        formulae.each do |name|
          begin
            formula_name = File.basename name, '.rb'
            formula_class = Formula.class_s(formula_name).to_sym
            if Object.const_defined? formula_class
              Object.send :remove_const, formula_class
              $LOADED_FEATURES.reject! { |p| p =~ /\/#{formula_name}.rb/ }
            end

            if backward_compat
              name = File.join path, name unless full? || name.start_with?(path)
              formula = Formula.factory name
            else
              if full?
                loader = Formulary::StandardLoader
              else
                loader = Formulary::FromPathLoader
                name = File.join path, name unless name.start_with?(path)
              end
              formula = loader.new(name).get_formula :stable
            end

            formulae_info[formula.name] = {
              deps: formula.deps.map(&:to_s),
              homepage: formula.homepage,
              keg_only: formula.keg_only? != false,
              stable_version: (formula.stable.version.to_s rescue nil),
              devel_version: (formula.devel.version.to_s rescue nil),
              head_version: (formula.head.version.to_s rescue nil)
            }

            if formulae_info[formula.name][:stable_version].nil? &&
                formulae_info[formula.name][:devel_version].nil? &&
                formulae_info[formula.name][:head_version].nil?
              formulae_info[formula.name][:stable_version] = formula.version.to_s
            end
          rescue FormulaUnavailableError, NoMethodError, RuntimeError,
                 SyntaxError, TypeError
            error_msg = "Formula '#{name}' could not be imported because of an error:\n" <<
                    "    #{$!.class}: #{$!.message}"
            Rails.logger.warn error_msg
            if defined?(Airbrake) && !Airbrake.configuration.api_key.nil?
              Airbrake.notify $!, { error_message: error_msg }
            end
          end
        end

        File.binwrite tmp_file, Marshal.dump(formulae_info)
      rescue
        File.binwrite tmp_file, Marshal.dump($!)
      end
    end

    Process.wait pid
    formulae_info = Marshal.load File.binread(tmp_file)
    tmp_file.unlink
    if formulae_info.is_a? StandardError
      raise formulae_info, formulae_info.message, formulae_info.backtrace
    end

    formulae_info
  end

  def formula_regex
    full? ? /^(?:Library\/)?Formula\/(.+?)\.rb$/ : /^(.+?\.rb)$/
  end

end
