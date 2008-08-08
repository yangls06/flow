require 'mkmf'

$defs << "-DRUBY_VERSION_CODE=#{RUBY_VERSION.gsub(/\D/, '')}"
$src = ["ebb_parser.c", "ebb_request_parser.c"]
dir_config("ebb_parser")
create_makefile('ebb_parser')
