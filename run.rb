require 'merlion/game/acpc'
require 'ruby-prof'
game = Merlion::Game::ACPC.new(server: 'localhost', port: 27700)
#RubyProf.start
begin
	game.main_loop
rescue Interrupt => e
#	result = RubyProf.stop
#	gp = RubyProf::GraphHtmlPrinter.new(result)
#	File.open('/tmp/rprof.html', 'w') {|f| gp.print(f)}
end
