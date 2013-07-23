class Merlion
	class FBS
		def self.get_move(player)
			game = player.game
			hs = player.hand_strength
			to_call = player.to_call

			if hs > 0.85
				return [0,0.1,0.9]
			elsif to_call > 0
				if rand() < hs ** (1 + (player.bets_to_call))
					# value raise
					return [0,0,1]
				end
				# pot odds removed
				if (hs * hs * game.pot > player.to_call)
					# strong enough hand to call
					return [0,1,0]
				end
				# fold/bluff
				return [0.95,0,0.05]
			else
				if rand() < hs * hs
					# value bet
					return [0,0,1]
				end
#				if rand() < ppot
#					# semi-bluff
#					return [0,0,1]
				end
				# check/bluff
				return [0.85,0,0.15]
		end
	end
end
