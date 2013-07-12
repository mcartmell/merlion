require 'pokereval'
require 'merlion/log'

class Merlion
	class Player
		include Merlion::Log
		attr_accessor :folded, :acted, :put_in_this_round, :hole_cards, :seat
		attr_reader :name, :pe, :yields_for_move
		attr_accessor :game, :has_quit
		attr_accessor :stack
		attr_accessor :seats_from_dealer, :last_action

		def initialize(opts = {}) 
			@stack = opts[:stack]
			@game = opts[:game]
			@name = opts[:name]
			@seat = opts[:seat]
			@yields_for_move = false
			@out = false
			@has_quit = false
			@pe = PokerEval.new
		end

		def hole_str
			@hole_cards
		end

		def has_hole_cards?
			return (hole_cards && hole_cards.length == 4)
		end

		# Resets state to the start of a hand
		def rewind!
			self.folded = false
			self.acted = false
			self.hole_cards = ''
			self.put_in_this_round = 0
			self.seats_from_dealer = @game.active_seats_from_dealer(self.seat)
			self.last_action = nil
			if self.stack == 0
				@out = true
			end
		end

		def out?
			@out
		end

		# @return [Boolean] Is it this player's turn?
		def to_act?
			return self == game.player_to_act
		end

		# @return [Boolean] Is this player still in the hand?
		def still_in_hand?
			return !folded? && !out?
		end

		# @return [Boolean] Is this player still to act?
		def still_to_act?
			return active? && !finished_round?
		end

		# @return [Boolean] Has this player folded in this round?
		def folded?
			return @folded
		end

		# @return [Boolean] Has this player acted yet?
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

		def check
			@acted = true
			@last_action = :check
		end

		def check_or_fold
			if to_call == 0
				return check
			else
				return fold
			end
		end

		# Calls the current bet, whatever the size
		def call
			if to_call == 0
				return check
			end
			bet(to_call)
			@acted = true
			@last_action = :call
		end

		# Folds the player's hand
		def fold
			@folded = true
			@acted = true
			@last_action = :fold
		end

		# Raises by the amount given, or by the minimum bet
		def bet_raise (amount = nil)
			unless amount
				if game.bets_this_round == 4
					# Hit the limit for raises this round, so just call
					return call
				end
				amount = to_call + @game.minimum_bet
			end
			bet(amount)
			@acted = true
			if to_call > 0
				@last_action = :raise
			else
				@last_action = :bet
			end
		end

		# Puts in the small blind
		def small_blind
			amount = @game.small_blind
			bet(amount)
		end

		# Puts in the big blind
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
			return "#{self.object_id} #{self.class} [#{name}/#{stack}/#{active?} #{hole_str}]"
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

		# @return [Boolean] Does the player have suited hole cards?
		def has_suited?
			return hole_str.match(/([hscd]).\1/) != nil
		end

		# @return [Boolean] Does the player have connected hole cards?
		def has_connected?
			(card1, card2) = hole_str.gsub(/[hcsd]/, '').split(//).map{|c| pe.rank_to_num(c)}
			return ((card1 - card2).abs == 1)
		end

		# @return [Boolean] Does the player have connected-but-one hole cards?
		def has_connected_but_one?
			(card1, card2) = hole_str.gsub(/[hcsd]/, '').split(//).map{|c| pe.rank_to_num(c)}
			return ((card1 - card2).abs == 2)
		end

		# Called when a new hand has started
		def hand_started
		end

		# A callback for when the state has changed
		def state_changed
		end

		# A callback for when a new stage has begun
		def stage_changed
		end

		# A callback for when a hand is over
		def hand_finished
		end

		# A callback for when the player receives their hole cards
		def hole_cards_received
		end

		# Mark the player as quit, to be removed at the end of the hand
		def quit
			self.has_quit = true
		end

		def hole_cards_ary
			return hole_cards.scan(/../)
		end

		def to_hash
			hash = {}
			hash[:name] = name
			hash[:seat] = seat
			hash[:stack] = stack
			hash[:put_in] = put_in_this_round
			hash[:last_action] = last_action
			return hash
		end

		def hand_type
			return pe.type_hand(hole_cards, game.board_cards)
		end
	end

end
