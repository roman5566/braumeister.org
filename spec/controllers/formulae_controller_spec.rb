# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2014, Sebastian Staudt

require 'rails_helper'

describe FormulaeController do

  describe '#select_repository' do
    it 'sets the repository' do
      repo = mock
      Repository.expects(:find).with('adamv/homebrew-alt').returns repo
      controller.expects(:params).twice.returns({ repository_id: 'adamv/homebrew-alt' })

      controller.send :select_repository

      expect(controller.instance_variable_get(:@repository)).to eq(repo)
    end

    it 'redirects to the short url for Repository::MAIN' do
      request = mock
      request.expects(:url).twice.returns "http://braumeister.org/repos/#{Repository::MAIN}/browse"
      controller.expects(:request).twice.returns request
      controller.expects(:redirect_to).with '/browse'

      controller.send :select_repository
    end

    it 'the repository defaults to Repository::MAIN' do
      repo = mock
      Repository.expects(:find).with(Repository::MAIN).returns repo

      controller.send :select_repository

      expect(controller.instance_variable_get(:@repository)).to eq(repo)
    end

    it 'redirects to the correct repository if capitalization is incorrect'

    it 'raises Mongoid::Errors::DocumentNotFound if no repository is found'
  end

  describe '#show' do
    context 'when formula is not found' do
      before do
        repo = mock
        formulae = mock
        Repository.expects(:find).with('adamv/homebrew-alt').returns repo
        repo.expects(:formulae).twice.returns formulae
        formulae.expects(:where).returns []
        formulae.expects(:all_in).returns []

        @controller.stubs :index
        bypass_rescue
      end

      it 'should raise an error' do
        expect(-> { get :show, repository_id: 'adamv/homebrew-alt', id: 'git' }).
          to raise_error(Mongoid::Errors::DocumentNotFound)
      end
    end
  end

end
