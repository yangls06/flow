require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'
require 'rake/clean'

SRC = ["ext/ebb_request_parser.h", "ext/ebb_request_parser.c", "ext/ebb_parser.c"]
CLEAN.add ["**/*.{o,bundle,so,obj,pdb,lib,def,exp}"]
CLOBBER.add ['ext/Makefile', 'ext/mkmf.log']

task(:default => :compile)

task :compile => ['ext/Makefile'] do
  sh "cd ext && make"
end

file('ext/Makefile' => SRC+['ext/extconf.rb']) do
  sh "cd ext && ruby extconf.rb"
end

file "ext/ebb_request_parser.c" => "ext/ebb_request_parser.rl" do
  sh 'ragel -s -G2 ext/ebb_request_parser.rl'
end

LIBEBBFILES = %w{ebb_request_parser.rl ebb_request_parser.h}
LIBEBBFILES.each do |f|
  file(".libebb/#{f}" => ".libebb") 
  file("ext/#{f}" => ".libebb/#{f}") do |t|
    sh "cp .libebb/#{f} ext/#{f}"
  end
end

file ".libebb" do
  sh "git clone git://github.com/ry/libebb.git .libebb"
end
