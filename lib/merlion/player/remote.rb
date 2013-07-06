require 'merlion/player'
require 'merlion/util'
require 'merlion/log'

class Merlion
	class Player
		class Remote < Merlion::Player
			include Merlion::Log
			include Merlion::Util

			def initialize(opts = {})
				super
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

		end
	end
end
