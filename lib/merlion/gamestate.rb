class Merlion
	class GameState
		attr_accessor :small_blind, :big_blind, :current_bet, :pot, :board_cards, :dealer, :stage_num, :current_player, :players
		def duplicate
			dup = clone
			newplayers = []
			players.each_with_index do |p,i|
				newplayers[i] = p.clone
			end
			dup.players = newplayers
			dup
		end
	end
end
