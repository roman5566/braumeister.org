# This code is free software; you can redistribute it and/or modify it under
# the terms of the new BSD License.
#
# Copyright (c) 2014, Sebastian Staudt

class ActionDispatch::Journey::Visitors::Formatter

  def visit_SYMBOL(node, name)
    if value = options[name]
      escape_path value
    end
  end

end
