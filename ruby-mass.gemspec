# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ["Paul Engel"]
  gem.email         = ["paul.engel@holder.nl"]
  gem.description   = %q{Introspect the Ruby Heap by listing, counting, searching references to and detaching (releasing) objects - optionally narrowing by namespace}
  gem.summary       = %q{Introspect the Ruby Heap by listing, counting, searching references to and detaching (releasing) objects - optionally narrowing by namespace}
  gem.homepage      = "https://github.com/archan937/ruby-objects"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "ruby-mass"
  gem.require_paths = ["lib"]
  gem.version       = "0.1.0"
end