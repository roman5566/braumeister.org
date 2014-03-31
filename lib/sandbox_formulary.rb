class Formulary

  class << self
    alias_method :original_factory, :factory
  end

  def self.factory(ref)
    path = nil
    repo = Repository.all.detect { |repo| path = repo.find_formula ref }
    original_factory(path.nil? ? ref : File.join(repo.path, path))
  end

end
