require 'merlion/player/remote'
require 'merlion/log'
require 'merlion/game'
require 'merlion/defer'

class Merlion
	class Game
		# A 'local' game, meaning we are the host and can deal cards etc.
		class Local < Merlion::Game
			include Merlion::Log
			include Merlion::Defer

			attr_accessor :waiting_players
			attr_reader :fiber

			def initialize(opts = {})
				super
				# Our main fiber. Simply runs the default main loop from the superclass.
				@fiber = Fiber.new do
					main_loop
				end
				@waiting_players = []
				@game_id = 0
				set_initial_state!(opts)
			end

			# loop until we can start the hand
			def start_hand
				loop do
					hand_started = super
					self.game_id += 1
					break if hand_started
					Fiber.yield
				end
			end

			# Starts the game. Simply resumes the main loop fiber
			def start
				@fiber.resume
			end

			# Adds a player to the waiting list
			def add_player(opts = {})
				defaults = {
					name: "Anonymous"
				}
				opts = defaults.merge(opts)
				player = create_player(opts)
				self.waiting_players.push(player)
				return player
			end

			# Called when a player has been added. Unless the game is in progress, we
			# might need to start the game, so resume the main loop
			def player_added
				unless self.stage_num
					fiber.resume # get back to main loop
				end
			end

			# Seats a player by finding an empty seat and placing them.
			def add_players_to_seats
				return if waiting_players.empty?
				return if num_seated_players == num_players
				(1 .. num_players).each do |np|
					i = np - 1
					next if players[i] # already someone in this seat
					waiting_player = waiting_players.pop
					return unless waiting_player
					players[i] = waiting_player
					players[i].seat = i
					debug("New player in seat #{i}")
				end
			end

			# We don't create any players until they join the game
			def create_players
			end

			# Sets the initial state. We override the default_player_class
			def set_initial_state!(opts = {})
				defaults = {
					default_player_class: Merlion::Player::Remote,
					player_delay: 0
				}
				opts = opts.merge(defaults)
				initialize_from_opts(opts)
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
				move = nil
				if to_act.yields_for_move
					move = to_act.get_move
				else
					move = defer_move
				end
				return move
			end

			# Yields and resumes the fiber when we have the move.
			# Based on this pattern: http://www.igvita.com/2010/03/22/untangling-evented-code-with-ruby-fibers/
			def defer_move
				move = nil
				defer { move = player_to_act.get_move }
				Fiber.yield
				return move
			end

			# Sends each player an event notification, but does so as a deferred job
			# so they don't block. Only return when all jobs have completed
			def send_each_player(sym, *args)
				players.each do |p|
					defer { p.send(sym, *args) }
				end
				Fiber.yield
			end
		end
	end
end
