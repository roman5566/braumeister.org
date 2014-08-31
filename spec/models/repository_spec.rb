# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2014, Sebastian Staudt

require 'rails_helper'

describe Repository do

  let(:repo) { Repository.new name: Repository::MAIN, full: true }

  before do
    Repository.stubs(:find).with(Repository::MAIN).returns repo
  end

  describe '.main' do
    it "returns the repository object for #{Repository::MAIN}" do
      expect(Repository.main).to eq(repo)
    end
  end

  describe '#main?' do
    it "returns true for #{Repository::MAIN}" do
      expect(repo.main?).to be_truthy
    end

    it 'returns false for other repositories' do
      expect(Repository.new(name: 'adamv/homebrew-alt').main?).to be_falsey
    end
  end

  describe '#url' do
    it 'returns the Git URL of the GitHub repository' do
      expect(repo.url).to eq("git://github.com/#{Repository::MAIN}.git")
    end
  end

end
