# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2013, Sebastian Staudt

require 'spec_helper'

describe Repository do

  let(:repo) { Repository.new name: Repository::MAIN, full: true }

  describe '.main' do
    it "returns the repository object for #{Repository::MAIN}" do
      repo = mock
      Repository.expects(:find).with(Repository::MAIN).returns repo

      Repository.main.should eq(repo)
    end
  end

  describe '#main?' do
    it "returns true for #{Repository::MAIN}" do
      repo.main?.should be_true
    end

    it 'returns false for other repositories' do
      Repository.new(name: 'adamv/homebrew-alt').main?.should be_false
    end
  end

  describe '#path' do
    it 'returns the filesystem path of the Git repository' do
      repo.path.should eq("#{Braumeister::Application.tmp_path}/repos/#{Repository::MAIN}")
    end
  end

  describe '#url' do
    it 'returns the Git URL of the GitHub repository' do
      repo.url.should eq("git://github.com/#{Repository::MAIN}.git")
    end
  end

  describe '#git' do

    context 'can call Git commands' do

      let(:command) { "git --git-dir #{repo.path}/.git log" }

      it 'successfully' do
        repo.expects(:`).with(command).returns 'log output'
        `test 0 -eq 0`

        repo.git('log').should eq('log output')
      end

      it 'with errors' do
        repo.expects(:`).with(command).returns ''
        `test 0 -eq 1`

        -> { repo.git('log') }.should raise_error(RuntimeError, "Execution of `#{command}` failed.")
      end

    end

  end

  describe '#clone_or_pull' do

    it 'clones a new repository' do
      File.expects(:exists?).with(repo.path).returns false
      repo.expects(:git).with "clone --quiet #{repo.url} #{repo.path}"

      repo.clone_or_pull
    end

    it 'clones or updates the main repository for non-full repositories' do
      main_repo = mock
      Repository.expects(:main).returns main_repo
      main_repo.expects :clone_or_pull

      repo.expects(:full?).returns false
      File.expects(:exists?).with(repo.path).returns false
      repo.expects(:git).with "clone --quiet #{repo.url} #{repo.path}"

      repo.clone_or_pull
    end

    context 'updates an already known repository' do

      it 'and clones it if it doesn\'t exist yet' do
        File.expects(:exists?).with(repo.path).returns false
        repo.expects(:git).with "clone --quiet #{repo.url} #{repo.path}"

        repo.clone_or_pull
      end

      it 'and fetches updates if it already exists' do
        File.expects(:exists?).with(repo.path).returns true
        repo.expects(:git).with('fetch --force --quiet origin master')
        repo.expects(:git).with('diff --shortstat HEAD FETCH_HEAD').returns '1'
        repo.expects(:git).with("--work-tree #{repo.path} reset --hard --quiet FETCH_HEAD")

        repo.clone_or_pull
      end

    end

  end

  describe '#generate_history!' do
    it 'resets the repository and generates the history from scratch' do
      repo.revisions << Revision.new(sha: '01234567')
      repo.revisions << Revision.new(sha: 'deadbeef')
      repo.formulae << Formula.new(name: 'bazaar', revisions: repo.revisions)
      repo.formulae << Formula.new(name: 'git', revisions: repo.revisions)
      repo.authors << Author.new(name: 'Sebastian Staudt')

      repo.expects :update_status
      repo.expects :generate_history

      repo.generate_history!

      repo.revisions.should be_empty
      repo.authors.should be_empty
      repo.formulae.each { |formula| formula.revisions.should be_empty }
    end
  end

  describe '#refresh' do
    it 'does nothing when nothing has changed' do
      repo.expects(:update_status).returns [[], [], 'deadbeef']
      Rails.logger.expects(:info).with 'No formulae changed.'
      repo.expects(:generate_history).never

      repo.refresh
    end
  end

  describe '#formulae_info' do

    before do
      class FormulaUnavailableError; end

      def repo.fork
        yield
        1234
      end

      repo.expects :exit!
      Process.expects(:wait).with 1234

      io = StringIO.new
      io.expects(:close).times(4).with { io.rewind }
      IO.expects(:pipe).returns [io, io]

      repo.expects(:require).with 'sandbox_backtick'
      repo.expects(:require).with 'sandbox_io_popen'
      Object.expects(:remove_const).with :Formula
      repo.expects(:require).with 'Library/Homebrew/global'
      repo.expects(:require).with 'Library/Homebrew/formula'
      repo.expects(:require).with 'sandbox_macos'
    end

    it 'sets some global information on the repo path' do
      repo.expects(:path).returns 'path'
      $LOAD_PATH.expects(:unshift).with File.join('path')
      $LOAD_PATH.expects(:unshift).with File.join('path', 'Library', 'Homebrew')

      repo.send :formulae_info, []

      $homebrew_path.should eq('path')
    end

    it 'uses a forked process to load formula information' do
      class Formulary
        class StandardLoader; end
      end

      git = mock deps: [], homepage: 'http://git-scm.com', keg_only?: false, name: 'git', stable: mock(version: '1.7.9'), devel: nil, head: mock(version: 'HEAD')
      git_loader = mock get_formula: git
      memcached = mock deps: %w(libevent), homepage: 'http://memcached.org/', keg_only?: false, name: 'memcached', stable: mock(version: '1.4.11'), devel: mock(version: '2.0.0.dev') , head: nil
      memcached_loader = mock get_formula: memcached

      Formula.expects(:class_s).with('git').returns :Git
      Formulary::StandardLoader.expects(:new).with('git').returns git_loader
      Formula.expects(:class_s).with('memcached').returns :Memcached
      Formulary::StandardLoader.expects(:new).with('memcached').returns memcached_loader

      formulae_info = repo.send :formulae_info, %w{git memcached}
      formulae_info.should eq({
        'git' => { deps: [], homepage: 'http://git-scm.com', keg_only: false, stable_version: '1.7.9', devel_version: nil, head_version:'HEAD' },
        'memcached' => { deps: %w(libevent), homepage: 'http://memcached.org/', keg_only: false, stable_version: '1.4.11', devel_version: '2.0.0.dev', head_version: nil }
      })
    end

    it 'reraises errors caused by the subprocess' do
      Formula.expects(:class_s).with('git').raises StandardError.new('subprocess failed')

      ->() { repo.send :formulae_info, %w{git} }.should raise_error(StandardError, 'subprocess failed')
    end

  end

  describe '#formula_regex' do

    it 'returns a specific regex for full repos' do
      Repository.new(full: true).send(:formula_regex).should eq(/^(?:Library\/)?Formula\/(.+?)\.rb$/)
    end

    it 'returns a generic regex for other repos' do
      Repository.new.send(:formula_regex).should eq(/^(.+?\.rb)$/)
    end

  end

  describe '#update_status' do

    before do
      repo.expects :clone_or_pull
      repo.expects(:git).with('log -1 --format=format:"%H %ct" HEAD').
        returns 'deadbeef 1325844635'
    end

    it 'can get the current status of a new full repository' do
      repo.expects(:git).with('ls-tree --name-only HEAD Library/Formula/').
        returns "Library/Formula/bazaar.rb\nLibrary/Formula/git.rb\nLibrary/Formula/mercurial.rb"
      repo.expects(:git).with('ls-tree --name-only HEAD Library/Aliases/').
        returns "Library/Aliases/bzr\nLibrary/Aliases/hg"

      formulae, aliases, last_sha = repo.update_status

      formulae.should eq([%w{A Library/Formula/bazaar.rb}, %w{A Library/Formula/git.rb}, %w{A Library/Formula/mercurial.rb}])
      aliases.should eq([%w{A Library/Aliases/bzr}, %w{A Library/Aliases/hg}])
      last_sha.should be_nil
    end

    it 'can get the current status of a new tap repository' do
      repo.full = false
      repo.expects(:git).with('ls-tree --name-only -r HEAD').
        returns "bazaar.rb\ngit.rb\nmercurial.rb"

      formulae, aliases, last_sha = repo.update_status

      formulae.should eq([%w{A bazaar.rb}, %w{A git.rb}, %w{A mercurial.rb}])
      aliases.should eq([])
      last_sha.should be_nil
    end

    it 'can update the current status of a repository' do
      repo.sha = '01234567'
      repo.expects(:git).with('diff --name-status 01234567..HEAD').
        returns "D\tLibrary/Aliases/bzr\nA\tLibrary/Aliases/hg\nD\tLibrary/Formula/bazaar.rb\nM\tLibrary/Formula/git.rb\nA\tLibrary/Formula/mercurial.rb"
      Rails.logger.expects(:info).with "Updated #{Repository::MAIN} from 01234567 to deadbeef:"

      formulae, aliases, last_sha = repo.update_status

      formulae.should eq([%w{D Library/Formula/bazaar.rb}, %w{M Library/Formula/git.rb}, %w{A Library/Formula/mercurial.rb}])
      aliases.should eq([%w{D Library/Aliases/bzr}, %w{A Library/Aliases/hg}])
      last_sha.should eq('01234567')
    end

    after do
      repo.date.should eq(Time.at 1325844635)
      repo.sha.should eq('deadbeef')
    end

  end

end
