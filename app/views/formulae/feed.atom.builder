# encoding: utf-8

# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012, Sebastian Staudt

atom_feed :id => "tag:braumeister.org,2012:#{@repository.name}",
          :schema_data => 2012,
          'xmlns:opensearch' => 'http://a9.com/-/spec/opensearch/1.1/' do |feed|
  feed.title "braumeister.org – Recent changes in #{@repository.name}"
  feed.updated @repository.updated_at

  feed.link rel: 'search', href: '/opensearch.xml', title: 'braumeister.org – Search',
            type: 'application/opensearchdescription+xml'

  add_entry = ->(status, formula, revision) do
    entry_options = {
      id: "tag:braumeister.org,2012:#{@repository.name}/#{formula.name}-#{revision.sha}",
      published: revision.date,
      updated:   revision.date
    }

    feed.entry formula, entry_options do |entry|
      entry.title "#{formula.name} has been #{status}"
      entry.summary revision.subject

      entry.author do |author|
        author.name revision.author.name
      end
    end
  end

  @revisions.each do |revision|
    revision.added_formulae.each { |formula| add_entry.call('added', formula, revision) }
    revision.updated_formulae.each { |formula| add_entry.call('updated', formula, revision) }
    revision.removed_formulae.each { |formula| add_entry.call('removed', formula, revision) }
  end
end
