require 'merlion/log'

class Merlion
	class Lobby
		# Routes and responds to messages from clients
		module ConnHelper
			include Merlion::Log
			attr_reader :lobby
			attr_accessor :last_table

			# Called to handle a line of input from any server
			def handle(data)
				process_line(data)
			end

			# Writs back to the client. Should be overridden
			def write(msg)
				# object should implement send_data
				raise "Abstract method called"
			end

			# Abstract method
			def write_state_changed(p)
			end

			# Abstract method
			def write_stage_changed(p)
			end

			# Abstract method
			def write_hand_started(p)
			end

			# Abstract method
			def write_hand_finished(p)
			end

			# Abstract method
			def write_hole_cards(p)
			end

			# @return [String] The game list
			def get_games_list
				return lobby.get_games.map do |game|
					"#{game[:id]} (#{game[:players]}/#{game[:max_players]})"
				end.join("\n")
			end

			# Associates a player with this connection
			def add_player(game, player)
				@players ||= {}
				@players[game.table_id] = player
			end

			# Removes a player from this connection
			def remove_player(table_id)
				player_for(table_id).quit
				@players.delete(table_id)
			end

			# Remove the player from all active games.
			def remove_from_all_tables
				return if !@players || @players.empty?
				@players.values.each do |p|
					p.quit
				end
			end

			# Gets the player instance associated with a given table id
			def player_for(table_id)
				pl = @players[table_id]
				raise "No such table #{table_id}" unless pl
				return pl
			end

			# The main command handler
			def process_line(line)
				line.chomp!
				l = line.split(/\s+/)
				cmd = l[0]
				# Remember the last table for convenience when typing
				table_id = l[1] ? l[1].to_i : last_table
				self.last_table = table_id

				channel = cmd

				resp = nil
				begin
					resp = case cmd
					# Check for valid commands
					when 'list'
						get_games_list
					when 'join'
						name = l[2]
						lobby.add_player_to_game(table_id, name, self)
					when /(call|fold|raise)/
						player_for(table_id).line_received(cmd[0])
					when 'leave'
						remove_player(table_id)
					when 'quitall'
						remove_from_all_tables
					else
						unknown_cmd(cmd)
					end
				rescue Exception => e
					channel = 'error'
					resp = create_error(e)
					puts e.message
					puts e.backtrace.join("\n")
				end

				if resp
					# Write our response. The format is left to the connection class (eg. json, text)
					write(resp, channel)
				end
			end

			# An 'unknown command' message
			def unknown_cmd(cmd)
				"Unknown command: #{cmd}"
			end

			# An error message
			def create_error(e)
				return "Error: #{e.message}"
			end
		end
	end
end

