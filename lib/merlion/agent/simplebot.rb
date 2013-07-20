require 'merlion/log'
class Merlion
	# A simple formula-based bot, based on https://code.google.com/p/opentestbed/
	class SimpleBot < Merlion::Player
		include Merlion::Log
		def get_move
			probs = case game.stage
				when :preflop
					pre_flop
				else
					post_flop
			end
			return act_triplet(probs)
		end

		# Picks an action from a triplet
		def act_triplet(probs)
			tot = 0
			trip = probs.map{|e| tot += e; tot.to_f.round(3)}
			rnd = Random.rand(tot)
			return :check_or_fold if rnd <= trip[0]
			return :call if rnd <= trip[1]
			return :bet_raise
		end

		# Pre-flop actions
		def pre_flop
			sg = sklansky_group
			# premium hands, raise
			if sg < 2
				return [0,0.05,0.95]
			elsif sg < 6
				if bets_to_call > 1
					# too expensive to call, usually fold
					return [0.75,0.25,0]
				elsif one_bet_to_call
					# worth calling
					return [0,0.8,0.2]
				elsif bets_to_call == 0
					# first to bet, be aggressive
					return [0,0.3,0.7]
				end
			elsif sg < 8
				# call for one bet, otherwise fold
				if one_bet_to_call
					return [0,0.95,0,05]
				else
					return [0.95,0,0.05]
				end
			else
				# trash. nearly always fold
				return [0.95,0,0.05]
			end
		end

		# effective hand strength
		def ehs
			return (pe.effective_hand_strength(hole_str, game.board_str))
		end

		# Post-flop actions
		def post_flop
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
	end
	class SimpleBotLoose < SimpleBot
		def pre_flop
			if sklansky_group < 3
				return [0,0,1]
			else
				return [0.1,0.8,0.1]
			end
		end
	end
end
