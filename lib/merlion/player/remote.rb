require 'merlion/player'
require 'merlion/util'
require 'merlion/log'

class Merlion
	class Player
		# Represents any player that we can directly communicate with and receive moves from
		class Remote < Merlion::Player
			include Merlion::Log
			include Merlion::Util

			MoveTimeout = 30

			attr_accessor :conn

			# Constructor
			def initialize(opts = {})
				super
				self.conn = opts[:conn]
				@yields_for_move = true
			end

			# Passes the player's move back to the game for processing
			# @param move [Symbol] The player's move
			def move_received(move)
				if to_act?
					debug "Got move from player: #{move}"
					# Received a valid move from the player. We resume the fiber to continue the game.
					return game.fiber.resume(move)
				else 
					debug "Doing nothing with #{move}"
				end
			end

			# Converts a player's command into an action symbol
			# @param line [String] The line of data received from the client
			def line_received(line)
				move = action(line)
				return move_received(move)
			end

			# @return [Boolean] Has the player quit?
			def has_quit?
				self.has_quit
			end

			# Yields for input from the player
			# @return [Symbol] The player's move
			def get_move
				# In order to get the move we must wait for input, so we yield here until we get a callback
				return :check_or_fold if has_quit?
				timer = EM::Timer.new(MoveTimeout) do
					game.fiber.resume(:check_or_fold)
				end
				move = Fiber.yield
				timer.cancel
				return move
			end	

			# Callback
			def state_changed
				conn.write_state_changed(self)
			end

			# Callback
			def stage_changed
				conn.write_stage_changed(self)
			end

			# Callback
			def player_moved
				conn.write_player_moved(self)
			end

			# Callback
			def hand_started
				conn.write_hand_started(self)
			end

			# Callback
			def hand_finished
				conn.write_hand_finished(self)
			end

			# A callback for when the player receives their hole cards
			def hole_cards_received
				conn.write_hole_cards(self)
			end

			# Write to the remote client
			def write(msg)
				conn.write(msg)
			end

		end
	end
end
