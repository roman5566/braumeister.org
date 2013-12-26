# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2013, Sebastian Staudt

Repository.find_or_create_by name: 'Homebrew/homebrew'
Repository.find_or_create_by name: 'Homebrew/homebrew-apache'
Repository.find_or_create_by name: 'Homebrew/homebrew-binary'
Repository.find_or_create_by name: 'Homebrew/homebrew-boneyard'
Repository.find_or_create_by name: 'Homebrew/homebrew-completions'
Repository.find_or_create_by name: 'Homebrew/homebrew-dupes'
Repository.find_or_create_by name: 'Homebrew/homebrew-games'
Repository.find_or_create_by name: 'Homebrew/homebrew-headonly'
Repository.find_or_create_by name: 'Homebrew/homebrew-science'
Repository.find_or_create_by name: 'Homebrew/homebrew-versions'

Repository.all.each do |repo|
  repo.refresh
  repo.save!
end
