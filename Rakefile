require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'
require 'rake/clean'

require File.dirname(__FILE__) + "/lib/flow/version"

SRC = ["ext/ebb_request_parser.h", "ext/ebb_request_parser.c", "ext/flow_parser.c"]
CLEAN.add ["**/*.{o,bundle,so,obj,pdb,lib,def,exp}"]
CLOBBER.add ['ext/Makefile', 'ext/mkmf.log', 'pkg', '.libebb', "ext/ebb_request_parser.*"]

DISTFILES = SRC + %w{
  ext/extconf.rb
  ext/ebb_request_parser.rl
  lib/flow.rb
  lib/flow/version.rb
  README
  Rakefile
  async_example.rb
  application.rb
}

task(:default => :compile)

task :compile => ['ext/Makefile'] do
  sh "cd ext && make"
end

file('ext/Makefile' => SRC+['ext/extconf.rb']) do
  sh "cd ext && ruby extconf.rb"
end

file "ext/ebb_request_parser.c" => "ext/ebb_request_parser.rl" do
  sh 'ragel -s ext/ebb_request_parser.rl'
end

%w{ebb_request_parser.rl ebb_request_parser.h}.each do |f|
  file(".libebb/#{f}" => ".libebb") 
  file("ext/#{f}" => ".libebb/#{f}") do |t|
    sh "cp .libebb/#{f} ext/#{f}"
  end
end

file ".libebb" do
  sh "git clone git://github.com/ry/libebb.git .libebb"
end

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.summary = s.description = "A Web Server"
  s.name = 'flow'
  s.author = 'ry dahl'
  s.email = 'ry at tiny clouds dot org'
  s.homepage = 'http://flow.rubyforge.org'
  s.version = Flow::VERSION
  s.rubyforge_project = 'flow'
  
  s.add_dependency('rev', '>= 0.2.2')
  s.required_ruby_version = '>= 1.9.0'
  
  s.require_path = 'lib'
  s.extensions = 'ext/extconf.rb'
  
  s.files = DISTFILES
end


Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
end
task(:package => DISTFILES)
