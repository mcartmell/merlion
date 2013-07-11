require 'merlion/player'
require 'merlion/util'
require 'merlion/log'

class Merlion
	class Player
		# Represents any player that we can directly communicate with and receive moves from
		class Remote < Merlion::Player
			include Merlion::Log
			include Merlion::Util

			attr_accessor :conn

			def initialize(opts = {})
				super
				self.conn = opts[:conn]
				@yields_for_move = true
			end

			def move_received(move)
				if to_act?
					debug "Got move from player: #{move}"
					# Received a valid move from the player. We resume the fiber to continue the game.
					return game.fiber.resume(move)
				else 
					debug "Doing nothing with #{move}"
				end
			end

			def line_received(line)
				move = action(line)
				return move_received(move)
			end

			def get_move
				# In order to get the move we must wait for input, so we yield here until we get a callback
				timer = EM::Timer.new(30) do
					game.fiber.resume(:check_or_fold)
				end
				move = Fiber.yield
				timer.cancel
				return move
			end	

			def state_changed
				conn.write_state_changed(self)
			end

			def stage_changed
				conn.write_stage_changed(self)
			end

			def hand_started
				conn.write_hand_started(self)
			end

			def hand_finished
				conn.write_hand_finished(self)
			end

			# A callback for when the player receives their hole cards
			def hole_cards_received
				conn.write_hole_cards(self)
			end

			def write(msg)
				conn.write(msg)
			end

		end
	end
end
