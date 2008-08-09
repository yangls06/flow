require 'mkmf'

$defs << "-DRUBY_VERSION_CODE=#{RUBY_VERSION.gsub(/\D/, '')}"
$src = ["flow_parser.c", "ebb_request_parser.c"]
dir_config("flow_parser")
create_makefile('flow_parser')
