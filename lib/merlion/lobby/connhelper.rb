require 'merlion/log'

class Merlion
	class Lobby
		# Routes and responds to messages from clients
		module ConnHelper
			include Merlion::Log
			attr_reader :lobby
			attr_accessor :last_table

			def handle(data)
				process_line(data)
			end

			def write(msg)
				# object should implement send_data
				raise "Abstract method called"
			end

			def write_state_changed(p)
			end

			def write_stage_changed(p)
			end

			def write_hand_started(p)
			end

			def write_hand_finished(p)
			end

			def get_games_list
				return lobby.get_games.map do |game|
					"#{game[:id]} (#{game[:players]}/#{game[:max_players]})"
				end.join("\n")
			end

			# Adds a new player to this 
			def add_player(game, player)
				@players ||= {}
				@players[game.table_id] = player
			end

			def remove_player(table_id)
				player_for(table_id).quit
				@players.delete(table_id)
			end

			def player_for(table_id)
				return @players[table_id]
			end

			# The main command handler
			def process_line(line)
				line.chomp!
				l = line.split(/\s+/)
				cmd = l[0]
				table_id = l[1] ? l[1].to_i : last_table
				self.last_table = table_id

				channel = cmd

				resp = nil
				begin
					resp = case cmd
					when 'list'
						get_games_list
					when 'join'
						lobby.add_player_to_game(table_id, self)
					when /(call|fold|raise)/
						player_for(table_id).line_received(cmd[0])
					when 'leave'
						remove_player(table_id)
					else
						unknown_cmd(cmd)
					end
				rescue Exception => e
					channel = 'error'
					resp = create_error(e)
				end

				if resp
					write(resp, channel)
				end
			end

			def unknown_cmd(cmd)
				"Unknown command: #{cmd}"
			end

			def create_error(e)
				return "Error: #{e.message}"
			end
		end
	end
end

