# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2012-2014, Sebastian Staudt

class Author

  include Mongoid::Document

  field :_id, type: String, default: ->{ email }
  field :email, type: String
  field :name, type: String

  belongs_to :repository, validate: false
  has_many :revisions, validate: false

end
