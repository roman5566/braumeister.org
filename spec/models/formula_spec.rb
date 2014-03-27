# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2014, Sebastian Staudt

require 'spec_helper'

describe Formula do

  let :formula do
    repo = Repository.new name: Repository::MAIN, full: true
    Formula.new name: 'git', repository: repo
  end

  describe '#generate_history!' do
    it 'resets and regenerates the history of the formula' do
      formula.repository.stubs(:generate_formula_history).with formula
      formula.revisions = [ Revision.new, Revision.new, Revision.new ]

      formula.generate_history!

      formula.revisions.should eq []
    end
  end

  describe '#set_id' do
    it 'should update the formula’s id' do
      formula.send :set_id

      formula.id.should eq "#{Repository::MAIN}/git"
    end
  end

  describe '#update_metadata' do
    it 'updates the metadata of the formula' do
      formula_info = {
        homepage: 'http://example.com',
        keg_only: true,
        stable_version: '1.0.0',
        devel_version:  '1.1.0.beta',
        head_version: 'HEAD'
      }

      formula.update_metadata formula_info

      formula.homepage.should eq 'http://example.com'
      formula.keg_only.should be true
      formula.stable_version.should eq '1.0.0'
      formula.devel_version.should eq '1.1.0.beta'
      formula.head_version.should eq 'HEAD'
    end
  end

  describe '#version' do
    it 'should return the stable version if it is available' do
      formula.stable_version = '1.0.0'
      formula.devel_version = '1.1.0.beta'
      formula.head_version = 'HEAD'

      formula.version.should eq '1.0.0'
    end

    it 'should return the devel version if it is available and no stable version exists' do
      formula.devel_version = '1.1.0.beta'
      formula.head_version = 'HEAD'

      formula.version.should eq '1.1.0.beta'
    end

    it 'should return the head version if no other version exists' do
      formula.head_version = 'HEAD'

      formula.version.should eq 'HEAD'
    end
  end

  context 'for a formula in a full repository' do

    describe '#path' do
      it 'returns the relative path' do
        formula.path.should eq('Library/Formula/git.rb')
      end
    end

    describe '#raw_url' do
      it 'returns the GitHub URL of the raw formula file' do
        formula.raw_url.should eq("https://raw.github.com/#{Repository::MAIN}/HEAD/Library/Formula/git.rb")
      end
    end

  end

  context 'for a formula in an alternative repository' do

    let :formula do
      repo = Repository.new name: 'adamv/homebrew-alt', full: false
      Formula.new name: 'php', path: 'duplicates', repository: repo
    end

    describe '#path' do
      it 'returns the relative path' do
        formula.path.should eq('duplicates/php.rb')
      end
    end

    describe '#raw_url' do
      it 'returns the GitHub URL of the raw formula file' do
        formula.raw_url.should eq('https://raw.github.com/adamv/homebrew-alt/HEAD/duplicates/php.rb')
      end
    end

  end

end
