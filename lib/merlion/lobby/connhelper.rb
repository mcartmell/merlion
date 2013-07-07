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

			def get_games_list
				return lobby.get_games.map do |game|
					"#{game[:id]} (#{game[:players]}/#{game[:max_players]})"
				end.join("\n")
			end

			def process_line(line)
				line.chomp!
				l = line.split(/\s+/)
				cmd = l[0]
				resp = 
				case cmd
				when 'list'
					get_games_list
				else
					if self.player
						self.player.line_received(line)
					end
					unknown_cmd(cmd)
					#lobby.add_player_to_game(0, self)
					#
					#puts "got some line from player: #{line}"
				end

				if resp
					write(resp)
				end
			end

			def unknown_cmd(cmd)
				"Unknown command: #{cmd}"
			end
		end
	end
end

