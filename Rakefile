#!/usr/bin/env rake
require "bundler/gem_tasks"
require "rake/testtask"

task :default => :test

Rake::TestTask.new do |test|
  test.pattern = "test/**/test_*.rb"
end

desc "Generate documentation for RubyMass"
task :rdoc do
  system "rdoc -f horo -t 'RubyMass documentation' -a README.rdoc lib/*"
end