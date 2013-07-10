require 'merlion/player'
require 'merlion/bot'
require 'merlion/log'
require 'merlion/util'
require 'pokereval'
require 'colorize'

class Merlion
	class Game
		include Merlion::Log
		include Merlion::Util
		attr_accessor :small_blind, :big_blind, :num_players, :current_bet, :pot, :board_cards, :dealer, :stage_num, :current_player, :players, :last_player_to_act, :game_id, :min_players, :max_players, :current_hand_history
		attr_reader :stacks, :names, :pe
		attr_reader :default_player_class, :player_delay

		Stages = [:preflop, :flop, :turn, :river, :game_finished]
		# The main loop. Should not need to be overridden
		def main_loop
			loop do
				move = get_next_move
				process_move(move)
			end
		end

		def initialize(opts = {})
			@pe = PokerEval.new
		end

		# Initializes the game to a given state. Can be used when the state of the
		# game changes (eg. a player quits), not just when the table opens
		def initialize_from_opts(opts = {})
			default = {
				small_blind: 1,
				big_blind: 2,
				names: [],
				default_player_class: Merlion::Player,
				min_players: 2,
				max_players: 10,
				player_delay: 0
			}
			opts = default.merge(opts)

			@small_blind = opts[:small_blind]
			@big_blind = opts[:big_blind]
			@num_players = opts[:num_players]
			@min_players = opts[:min_players]
			@max_players = opts[:max_players]
			@player_delay = opts[:player_delay]

			@current_player = 0

			@default_player_class = opts[:default_player_class]

			@names = opts[:names]
			@stacks = opts[:stacks] || [10000] * @num_players
			@players = []
			@dealer = opts[:dealer] || get_first_dealer

			create_players
		end

		# Creates the player objects
		def create_players
			@num_players.times do |i|
				@players[i] = create_player({seat: i})
			end
		end

		def seated_players
			return @players.select {|p| p != nil}
		end 

		def num_seated_players
			return seated_players.size
		end

		# Creates an individual player
		#
		#	@param index [Integer] The player's seat
		# @param type [Class] The class of player to create
		# @param name [String] The player's name
		def create_player(opts = {}) 
			seat = opts[:seat]
			if seat
				opts[:stack] ||= stacks[seat]
				opts[:name] ||= names[seat]
			end
			type = opts[:class] || self.default_player_class
			opts[:game] = self
			puts type
			obj = type.new(opts)
			return obj
		end

		def add_players_to_seats
		end

		def have_enough_players?
			return (num_seated_players >= min_players)
		end

		# Starts a new hand, resetting the state and pots, and commits the blinds
		def start_hand
			add_players_to_seats
			debug("Considering starting hand: #{num_seated_players} #{min_players}")
			return unless have_enough_players?
			unless self.dealer
				self.dealer = get_first_dealer
			end
			debug ("Starting hand")
			self.stage_num = 0
			self.pot = 0
			self.current_bet = 0
			self.current_player = first_to_act
			self.board_cards = ''
			self.last_player_to_act = nil
			self.current_hand_history = Array.new { [] } 
			players.each do |p|
				p.rewind!
			end
			players.each do |p|
				p.hand_started
			end
			deal_cards
			act('small_blind')
			act('big_blind')
		end

		def deal_preflop_cards
			used_cards = ''
			players.each do |p|
				p.hole_cards = (p.hole_cards || '') + pe.get_random_hand_not_in_str(used_cards)
				used_cards += p.hole_cards
			end
		end

		def deal_one_board_card
			deal_board_cards(1)
		end

		def deal_three_board_cards
			deal_board_cards(3)
		end

		def deal_board_cards(n)
			self.board_cards += pe.get_random_cards_not_in_str(all_cards_used, n)
		end

		def deal_cards
			case stage
			when :preflop
				deal_preflop_cards
				players.each {|p| p.hole_cards_received}
			when :flop
				deal_three_board_cards
			when :turn
				deal_one_board_card
			when :river
				deal_one_board_card
			else
				return
			end
		end

		# Clone this object, but clone the players too
		def duplicate
			newgame = self.clone
			newplayers = []
			newgame.players.each_with_index do |p, i|
				newplayers[i] = p.clone
				newplayers[i].game = newgame
			end
			return newgame
		end

		def get_first_dealer
			dealer = @current_player
			return if players.empty?
			loop do
				dealer = prev_seat(dealer)
				break unless players[dealer].out?
			end
			return dealer
		end

		# The last player to act
		def last_player
			players[last_player_to_act]
		end

		def inspect
			"#{stage.to_s.upcase.cyan} [#{render_cards(board_str)}] [#{pot}/#{current_bet} bet]"
		end

		# Prints the current state of the table
		def print_players
			players.each_with_index do |p, i|
				msg = i.to_s
				msg += 'd' if self.dealer == i
				msg += 'b' if self.bot_player == p
				msg += ' *' if self.current_player == i
				msg += '    out' if p.out?
				msg += '    folded' if p.folded?
				puts msg
			end
		end

		# @return [String] all the cards currently in play 
		def all_cards_used
			return board_cards + (players.map{|p| p.hole_cards}.join(''))
		end

		def board_str
			board_cards
		end

		# @return [Float] The minimum bet allowed
		def minimum_bet
			return (self.stage_num > 1 ? self.big_blind * 2 : self.big_blind)
		end

		def bets_this_round
			return (current_bet / minimum_bet)
		end


		# @return [Integer]
		def num_board_cards
			return (board_cards.length / 2)
		end

		# @return [Integer] The seat of the player to act first
		def first_to_act
			return heads_up? ? @dealer : next_notout_seat(@dealer)
		end

		def heads_up?
			return @num_players == 2
		end

		# Processes a move by proxying it to the current player object
		# Also calls the 'state_changed' callback
		def process_move(action, *args)
			return if !player_to_act
			player_to_act.send(action.to_sym, *args)
			player_finished
			state_changed
		end

		# Broadcasts a 'state changed' event to all players
		def state_changed
			players.each do |p|
				p.state_changed
			end
			sleep self.player_delay
			#print_players
		end

		# Broadcasts a 'stage changed' event to all players
		def stage_changed
			players.each do |p|
				p.stage_changed
			end
		end

		# @param player [Integer] The seat of the player putting in the pot
		# @param amount [Float] The size of the bet
		def put_in_pot(player, amount)
			@pot += amount
			player.stack -= amount
			if (player.put_in_this_round + amount > @current_bet)
				@current_bet = player.put_in_this_round + amount
			end
		end

		# @return [Merlion::Player] The current player object
		def player_to_act
			return nil unless self.current_player && have_enough_players?
			return self.players[self.current_player]
		end

		def next_notout_seat(i = nil, times = 1)
			return next_seat(i, times, true)
		end

		# @param i [Integer] The seat number to start from
		# @param times [Integer] The number of seats to loop through
		# @param exclude_out [Boolean] Whether or not to include players that are 'out' (have no chips remaining)
		def next_seat(i = nil, times = 1, exclude_out = true)
			return unless times
			seat = i || @current_player
			count = 0
			loop do
				seat = seat + 1
				seat = 0 if seat > (num_players - 1)
				if exclude_out
					count += 1 if players[seat] && !(players[seat].out?)
				else
					count += 1
				end
				break if count == times
			end
			return seat
		end

		# Like next_seat, but in reverse
		def prev_seat(i = nil, times = 1)
			seat = i || @current_player
			times.times do
				seat = seat - 1
				seat = (@players.size - 1) if seat < 0
			end
			return seat
		end

		def cycle_seats(start = nil, exclude_out = true)
			start = @current_player unless start
			seat = start
			first_seat = seat
			loop do
				yield @players[seat], seat
				seat = next_seat(seat, 1, exclude_out)
				break if seat == first_seat
			end
			return nil
		end

		def next_dealer
			return next_notout_seat(@dealer)
		end

		def active_seats_from_dealer(player)
			return 0 if self.dealer == player
			i = 1
			cycle_seats(next_seat(self.dealer)) do |p, idx|
				return i if idx == player
				if p.active?
					i = i + 1
				end
			end
		end

		def next_player_to_act(i = nil)
			cycle_seats(i) do |player, idx|
				return idx if player.still_to_act?
			end
			return nil
		end

		def has_got_enough_cards_for_stage?
			return false unless board_cards
			case stage
				when :preflop
					return num_board_cards == 0
				when :flop
					return num_board_cards == 3
				when :turn
					return num_board_cards == 4
				when :river
					return num_board_cards == 5
			end
		end

		# @return [Integer] The number of players currently active in this hand
		def num_active_players
			return active_players.size
		end

		# @return [Array[Merlion::Player]]
		def active_players
			return @players.select{|p| p.active?}
		end

		# Changes state to the next stage.
		# Broadcasts the stage_changed event to all players
		def next_stage
			if (stage == :river)
				self.current_player = nil
				hand_finished
			else
				self.stage_num = self.stage_num + 1
				self.current_bet = 0
				self.players.each do |player|
					player.put_in_this_round = 0
					player.acted = false
				end
				deal_cards
				@current_player = next_player_to_act(first_to_act)
				stage_changed
			end
		end

		# Called after a player has finished acting. May change the stage or end
		# the hand if necessary, otherwise changes to next player
		def player_finished
			debug("Player finished")
			self.last_player_to_act = current_player
			record_last_action

			if num_active_players == 1
				return hand_finished
			end

			if (next_player = next_player_to_act(next_seat))
				self.current_player = next_player
			else
				next_stage
			end
		end

		def record_last_action
			act = last_player.last_action
			(self.current_hand_history[self.stage_num] ||= []).push(act)
		end

		# Called after a hand has finished to resolve the winner
		def hand_finished
			debug("Hand finished")
			# one winner, reward them
			if (num_active_players == 1)
				winner = @players.find{|p| p.active?}
				winner.stack += self.pot
			else
				winners = active_players.select{|p| !p.hole_cards.empty?}.group_by{|p| pe.score_hand(p.hole_str, board_str)}
				winners = winners.max.last
				give_each = self.pot / winners.size
				winners.each do |winner|
					winner.stack += give_each
				end
			end

			record_hand_history

			players.each do |p|
				p.hand_finished
			end

			# set next dealer
			self.dealer = next_dealer

			start_hand
		end

		def record_hand_history
			p current_hand_history
			#TODO: write hand history to db, including dealer, board cards and hole cards
		end

		def set_initial_state!
		end

		def stage
			begin
				return Stages[self.stage_num]
			rescue
				return :not_started
			end
		end

		def table_id
			object_id
		end

		def board_cards_ary
			return [] unless board_cards
			board_cards.scan(/../)
		end

		def to_hash
			hash = {}
			hash[:stage] = stage
			hash[:pot] = pot
			hash[:current_player] = current_player
			hash[:cards] = board_cards_ary
			hash[:table_id] = table_id
			return hash
		end

		def to_hash_full
			h = to_hash
			h[:players] = players.map{|p| p.to_hash}
			return h
		end

		def bot_player
			nil
		end

		alias_method :act, :process_move
	end
end
