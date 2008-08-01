require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs += %w(atombot test .)
  t.test_files = ['test/*.rb']
end

task :default => [:test]
