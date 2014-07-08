# require 'core_ext' will fail if the time-warp gem is already loaded so we need
# to require the fully qualified path name instead

['core_ext', 'mass', 'ruby-mass/version'].each do |file|
  require File.join File.dirname(__FILE__), file
end
