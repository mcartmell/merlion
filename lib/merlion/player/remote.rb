require 'merlion/player'
require 'merlion/util'
require 'merlion/log'

class Merlion
	class Player
		class Remote < Merlion::Player
			include Merlion::Log
			include Merlion::Util

			attr_accessor :conn

			def initialize(opts = {})
				super
				self.conn = opts[:conn]
			end

			def move_received(move)
				if to_act?
					debug "Got move from player: #{move}"
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
				return Fiber.yield
			end	

			def state_changed
				write_state_changed(self)
			end

			def stage_changed
				write_stage_changed(self)
			end

			def hand_started
				write_hand_started(self)
			end

			def hand_finished
				write_hand_finished(self)
			end

			def 

			def write(msg)
				conn.write(msg)
			end

		end
	end
end
