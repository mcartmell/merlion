require 'merlion/analyzer'
table_name = ARGV.shift
raise "table_name required" unless table_name
man = Merlion::Analyzer.new
man.analyze_table_name(table_name)
