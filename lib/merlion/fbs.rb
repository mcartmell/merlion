class Merlion
	# A class to keep simple formula-based betting strategies
	class FBS
		# Predict a move using effective hand strength and potential
		def get_move_ehs(player, ehs)
			game = player.game
			to_call = player.to_call
			all_ehs = ehs
			ehs = all_ehs[:ehs] ** game.num_active_players
			ppot = all_ehs[:ppot]

			if ehs > 0.85
				return [0,0.1,0.9]
			elsif to_call > 0
				if rand() < ehs ** (1 + (bets_to_call))
					# value raise
					return [0,0,1]
				end
				if ppot > pot_odds
					# pot odds to call
					return [0,1,0]
				end
				if (ehs * ehs * game.pot > to_call)
					# strong enough hand to call
					return [0,1,0]
				end
				# fold/bluff
				return [0.95,0,0.05]
			else
				if rand() < ehs * ehs
					# value bet
					return [0,0,1]
				end
				if rand() < ppot
					# semi-bluff
					return [0,0,1]
				end
				# check/bluff
				return [0.85,0,0.15]
			end
		end

		# Predict a move using only hand strength
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
