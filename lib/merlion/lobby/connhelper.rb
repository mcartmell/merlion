require 'merlion/log'

class Merlion
	class Lobby
		module ConnHelper
			include Merlion::Log
			attr_accessor :player
			attr_reader :lobby

			def handle(data)
				process_line(data)
			end

			def write(msg)
				# object should implement send_data
				raise "Abstract method called"
			end

			def process_line(line)
				line.chomp!
				debug("Got: #{line}")
				if self.player
					self.player.line_received(line)
				else
					lobby.add_player_to_game(0, self)
					puts "got some line from player: #{line}"
				end
			end
		end
	end
end

