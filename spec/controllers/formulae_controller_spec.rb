# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2013, Sebastian Staudt

require 'spec_helper'

describe FormulaeController do

  describe '#select_repository' do
    it 'sets the repository' do
      repo = mock
      Repository.expects(:find).with('adamv/homebrew-alt').returns repo
      controller.expects(:params).twice.returns({ repository_id: 'adamv/homebrew-alt' })

      controller.send :select_repository

      controller.instance_variable_get(:@repository).should eq(repo)
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

      controller.instance_variable_get(:@repository).should eq(repo)
    end
  end

  describe '#show' do
    context 'when formula is not found' do
      subject { get :show, repository_id: 'adamv/homebrew-alt', id: 'git' }

      before do
        repo = mock
        formulae = mock
        Repository.expects(:find).with('adamv/homebrew-alt').returns repo
        repo.expects(:formulae).twice.returns formulae
        formulae.expects(:where).returns []
        formulae.expects(:all_in).returns []

        @controller.stubs :index
      end

      it do
        should render_template('application/index')
        flash.now[:error].should eq('The page you requested does not exist.')
      end
    end
  end

end
