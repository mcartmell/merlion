require 'pokereval'

class Merlion
	class Player
		attr_accessor :folded, :acted, :put_in_this_round, :hole_cards
		attr_reader :name, :last_action, :seat, :pe
		attr_accessor :game, :game_stack
		attr_accessor :stack

		def initialize(opts = {}) 
			@game_stack = opts[:stack]
			@game = opts[:game]
			@name = opts[:name]
			@seat = opts[:seat]
			@out = false
			@pe = PokerEval.new
			rewind!
		end

		def hole_str
			@hole_cards
		end

		def stage_finished
		end

		def rewind!
			@stack = @game_stack
			@folded = false
			@acted = false
			@put_in_this_round = 0
			@seats_from_dealer = @game.active_seats_from_dealer(self.seat)
			if @stack == 0
				@out = true
			end
		end

		def out?
			@out
		end

		def to_act?
			return self == game.player_to_act
		end

		def still_in_hand?
			return !folded? && !out?
		end

		def still_to_act?
			return active? && !finished_round?
		end

		def folded?
			return @folded
		end

		def acted?
			return @acted
		end

		def other_active_players
			game.active_players.select {|p| p != self}
		end

		def num_players_folded
			return game.players.select{|p| p.folded?}.size
		end

		def others_have_folded?
			return num_players_folded > 0
		end

		def pot_odds
			return nil if to_call == 0
			return (to_call.to_f / (game.pot + to_call))
		end

		def active?
			return !out? && !all_in? && !folded?
		end

		def active_and_finished?
			return active? && finished_round?
		end

		def finished_round?
			return acted? && called_enough?
		end

		def called_enough?
			return (put_in_this_round == @game.current_bet)
		end

		def all_in?
			return (@stack == 0)
		end

		def call!
			bet(to_call)
			@acted = true
			@last_action = 1
		end

		def bet(amount)
			if (stack > amount) 
				to_put_in = amount
			else
				to_put_in = @stack
			end
			@game.put_in_pot(self, to_put_in)
			self.put_in_this_round += to_put_in
		end

		def to_call
			return @game.current_bet - self.put_in_this_round
		end
		
		def small_bets_to_call
			return (to_call / game.small_blind)
		end

		def bets_to_call
			return (to_call / game.minimum_bet)
		end

		def one_bet_to_call
			return bets_to_call == 1
		end

		def has_bet_this_round?
			return (put_in_this_round > 0)
		end

		def fold!
			@folded = true
			@acted = true
			@last_action = 0
		end

		def raise!(amount = nil)
			unless amount
				amount = to_call + @game.minimum_bet
			end
			bet(amount)
			@acted = true
			@last_action = 2
		end

		def small_blind
			amount = @game.small_blind
			bet(amount)
		end

		def big_blind
			amount = @game.big_blind
			bet(amount)
		end

		def is_late_position?
			return (@seats_from_dealer >= (game.num_players - (game.num_players / 3)))
		end

		def is_early_position?
			return (@seats_from_dealer <= (game.num_players / 3))
		end

		def is_middle_position?
			return (!is_late_position? && !is_early_position?)
		end

		def to_s
			return name
		end

		def inspect
			return "[#{name}/#{stack}/#{active?} #{hole_str}]"
		end

		def sklansky_group
			return pe.hand_to_sklansky_group(hole_str)
		end

		def has_ace?
			return hole_str.include?('A')
		end

		def has_pocket_pair?
			(card1, card2) = hole_str.gsub(/[hcsd]/, '').split(//)
			return card1 == card2
		end

		def has_suited?
			return hole_str.match(/([hscd]).\1/) != nil
		end

		def has_connected?
			(card1, card2) = hole_str.gsub(/[hcsd]/, '').split(//).map{|c| pe.rank_to_num(c)}
			return ((card1 - card2).abs == 1)
		end

		def has_connected_but_one?
			(card1, card2) = hole_str.gsub(/[hcsd]/, '').split(//).map{|c| pe.rank_to_num(c)}
			return ((card1 - card2).abs == 2)
		end

		def state_changed
		end

		def hand_finished
		end

		def get_move
		end

	end
end
