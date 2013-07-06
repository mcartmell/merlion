require 'merlion/player'

class Merlion
	class Player
		class Remote < Merlion::Player

			def initialize(opts = {})
				super
			end

			def move_received(move)
				if to_act?
					return game.fiber.resume(move)
				end
			end

			def line_receieved(line)
				return move_received(line)
			end

			def get_move
				return Fiber.yield
			end

		end
	end
end
