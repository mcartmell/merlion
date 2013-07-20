class Merlion
	# A simple agent that always calls
	class CallBot < Merlion::Player
		# Always call.
		def get_move
			return :call
		end
	end
end
