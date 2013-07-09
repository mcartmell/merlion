require 'merlion/player/remote'
require 'merlion/log'
require 'merlion/game'

class Merlion
	class Game
		# A 'local' game, meaning we are the host and can deal cards etc.
		class Local < Merlion::Game
			include Merlion::Log

			attr_accessor :waiting_players
			attr_reader :fiber
			attr_reader :initial_stack

			def initialize(opts = {})
				super
				# Our main fiber. Simply runs the default main loop from the superclass.
				@fiber = Fiber.new do
					main_loop
				end
				@initial_stack = opts[:initial_stack] || 200
				@waiting_players = []
				set_initial_state!(opts)
			end

			def start
				start_hand
				@fiber.resume
			end

			# Adds a player to the waiting list
			def add_player(opts = {})
				defaults = {
					stack: self.initial_stack
				}
				opts = defaults.merge(opts)
				player = create_player(opts)
				self.waiting_players.push(player)
				return player
			end

			def player_added
				unless self.stage_num
					start_hand # try starting hand
					fiber.resume # get back to main loop
				end
			end

			# Seats a player by finding an empty seat and placing them.
			def add_players_to_seats
				debug("Considering adding players to seats")
				return if waiting_players.empty?
				return if num_seated_players == max_players
				(1 .. max_players).each do |np|
					i = np - 1
					next if players[i] # already someone in this seat
					waiting_player = waiting_players.pop
					return unless waiting_player
					players[i] = waiting_player
					players[i].seat = i
					debug("New player in seat #{i}")
				end
			end

			def create_players
			end

			def set_initial_state!(opts = {})
				defaults = {
					default_player_class: Merlion::Player::Remote,
					initial_stack: self.initial_stack
				}
				opts = opts.merge(defaults)
				initialize_from_opts(opts)
				start_hand
			end

			# Receives the next move from the current player.
			def get_next_move
				to_act = nil
				loop do
					to_act = player_to_act
					if to_act
						break
					else
						# We don't have enough players, or the game hasn't started. Wait for more.
						Fiber.yield
					end
				end
				return to_act.get_move
			end
		end
	end
end
