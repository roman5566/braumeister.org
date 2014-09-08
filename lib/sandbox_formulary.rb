class Formulary

  class << self
    alias_method :original_factory, :factory
  end

  def self.factory(ref)
    path = nil
    repo = Repository.all.detect do |repo|
      repo.extend RepositoryImport
      path = repo.find_formula ref
    end
    original_factory(path.nil? ? ref : File.join(repo.path, path))
  end

end
