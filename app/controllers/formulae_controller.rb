# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2013, Sebastian Staudt

require 'text'

class FormulaeController < ApplicationController

  before_filter :select_repository

  def browse
    if params[:search].nil? || params[:search].empty?
      letter = params[:letter]
      letter = 'a' if letter.nil? || letter.empty?
      @title = "Browse formulae – #{letter.upcase}"
      @title << " – #{@repository.name}" unless @repository.main?

      @formulae = @repository.formulae.letter(letter).where(removed: false).order_by([:name, :asc])
    else
      term = params[:search]
      @title = "Search for: #{term}"
      @title << " in #{@repository.name}" unless @repository.main?
      @formulae = @repository.formulae.
        where name: /#{Regexp.escape term}/i, removed: false

      if @formulae.size == 1 && term == @formulae.first.name
        if @repository.main?
          redirect_to formula_path(@formulae.first)
        else
          redirect_to repository_formula_path(@repository.name, @formulae.first)
        end
        return
      end

      @formulae = @formulae.order_by([:name, :asc]).sort_by do |formula|
        Text::Levenshtein.distance(formula.name, term) +
        Text::Levenshtein.distance(formula.name[0..term.size - 1], term)
      end
      @formulae = Kaminari.paginate_array @formulae
    end

    @letters = ('A'..'Z').select do |letter|
      @repository.formulae.letter(letter).where(removed: false).exists?
    end

    @formulae = @formulae.page(params[:page]).per 30

    fresh_when etag: @repository.sha, public: true
  end

  def feed
    @revisions = @repository.revisions.order_by([:date, :desc]).limit 50

    respond_to do |format|
      format.atom
    end

    fresh_when etag: @repository.sha, public: true
  end

  def show
    @formula = @repository.formulae.where(name: params[:id]).first
    if @formula.nil?
      formula = @repository.formulae.all_in(aliases: [params[:id]]).first
      unless formula.nil?
        if @repository.main?
          redirect_to formula
        else
          redirect_to repository_formula_path(@repository.name, formula)
        end
        return
      end
      raise Mongoid::Errors::DocumentNotFound.new(Formula, [], params[:id])
    end
    @title = @formula.name.dup
    @title << " – #{@repository.name}" unless @repository.main?
    @revisions = @formula.revisions.order_by([:date, :desc]).to_a
    @current_revision = @revisions.shift

    fresh_when etag: @current_revision.sha, public: true
  end

  private

  def select_repository
    main_repo_url = "/repos/#{Repository::MAIN}"
    if request.url.match main_repo_url
      redirect_to request.url.split(main_repo_url, 2)[1]
      return
    end

    params[:repository_id] ||= Repository::MAIN
    @repository = Repository.find params[:repository_id]
  end

end
