require 'forwardable'
require 'merlion/gamestate'
require 'merlion/player'
require 'merlion/log'
require 'merlion/db'
require 'merlion/util'
require 'pokereval'
require 'colorize'

class Merlion
	# Represents a basic game of hold'em.
	class Game
		extend Forwardable

		include Merlion::Log
		include Merlion::Util
		include Merlion::DB
		attr_accessor :num_players, :game_id, :min_players, :current_hand_history, :last_winners, :name, :last_player_to_act
		attr_reader :stacks, :names, :pe
		attr_reader :default_player_class, :default_stack, :player_delay
		attr_accessor :game_state

		def_delegators :@game_state, :small_blind, :small_blind=, :big_blind, :big_blind=, :current_bet, :current_bet=, :pot, :pot=, :board_cards, :board_cards=, :dealer, :dealer=, :stage_num, :stage_num=, :current_player, :current_player=, :players, :players=

		Stages = [:preflop, :flop, :turn, :river, :game_finished]

		# The main loop. Should not need to be overridden
		def main_loop
			loop do
				start_hand
				loop do
					move = get_next_move
					process_move(move)
					break if stage_num == nil
				end
			end
		end

		# Sets up the PokerEval object
		def initialize(opts = {})
			@pe = PokerEval.new
			@game_state = Merlion::GameState.new
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
				num_players: 10,
				player_delay: 0,
				last_winners: nil,
				stack: 200,
				name: "Game #{table_id}" 
			}
			opts = default.merge(opts)

			self.small_blind = opts[:small_blind]
			self.big_blind = opts[:big_blind]
			@num_players = opts[:num_players]
			@min_players = opts[:min_players]
			@player_delay = opts[:player_delay]
			@default_stack = opts[:stack]
			@name = opts[:name]

			self.current_player = 0

			@default_player_class = opts[:default_player_class]

			@names = opts[:names]
			@stacks = opts[:stacks] || [@default_stack] * @num_players

			self.players = []
			self.dealer = opts[:dealer] || get_first_dealer

			self.stage_num = nil

			create_players
		end

		# Creates the player objects
		def create_players
			@num_players.times do |i|
				self.players[i] = create_player({seat: i})
			end
		end

		# @return [Array[Merlion::Player]] The players that are currently seated in the game
		def seated_players
			return self.players.select {|p| p != nil}
		end 

		# @return [Integer] The number of players currently seated in the game
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
			opts[:stack] ||= self.default_stack
			opts[:game] = self
			obj = type.new(opts)
			return obj
		end

		# Called to add waiting players to seats
		def add_players_to_seats
		end

		# Removes players that have quit, and adjust seat numbers
		def remove_quit_players
			self.players.reject! {|p| p.has_quit }
			# update seat numbers
			self.players.each_with_index do |p, i|
				p.seat = i
			end
		end

		# @return [Boolean] Do we have enough players to start a game?
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
			send_each_player(:hand_started)
			deal_cards
			act('small_blind')
			act('big_blind')
			return true
		end

		# Returns true if the blinds have been posted this round
		def has_posted_blinds?
			stage_history && stage_history.size >= 2
		end

		# Deals hole cards to each player
		def deal_preflop_cards
			used_cards = ''
			players.each do |p|
				p.hole_cards = (p.hole_cards || '') + pe.get_random_hand_not_in_str(used_cards)
				used_cards += p.hole_cards
			end
		end

		# Deals one board card
		def deal_one_board_card
			deal_board_cards(1)
		end

		# Deals three board cards
		def deal_three_board_cards
			deal_board_cards(3)
		end

		# Deals n cards to the board, from the set of cards currently not in play
		# @param n [Integer] The number of cards to deal to the board
		def deal_board_cards(n)
			self.board_cards += pe.get_random_cards_not_in_str(all_cards_used, n)
		end

		# Gives cards to players and the board when starting a new stage Only
		# called for local games. Remote games (eg. when plugging in to Poker
		# Academy) should override this method
		def deal_cards
			case stage
			when :preflop
				deal_preflop_cards
				send_each_player(:hole_cards_received)
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
			gamestate = self.game_state.duplicate
			gamestate.players.each do |p|
				p.game = newgame
			end
			newgame.game_state = gamestate
			newgame.last_winners = last_winners.clone if last_winners
			return newgame
		end

		# @return [Integer] The seat number of the first dealer when starting a new game
		def get_first_dealer
			dealer = self.current_player
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

		# @return [Integer] The number of bets a player would have to call if they
		# were currently betting zero
		def bets_this_round
			return (current_bet / minimum_bet)
		end


		# @return [Integer]
		def num_board_cards
			return (board_cards.length / 2)
		end

		# @return [Integer] The seat of the player to act first
		def first_to_act
			return heads_up? ? self.dealer : next_notout_seat(self.dealer)
		end

		# @return [Boolean] Is this a heads-up game?
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
		# This is called after the player has acted
		def state_changed
			send_each_player(:state_changed)
			sleep self.player_delay
			#print_players
		end

		# Broadcasts a 'stage changed' event to all players
		def stage_changed
			send_each_player(:stage_changed)
			#p self
		end

		# @param player [Integer] The seat of the player putting in the pot
		# @param amount [Float] The size of the bet
		def put_in_pot(player, amount)
			self.pot += amount
			player.stack -= amount
			if (player.put_in_this_round + amount > self.current_bet)
				self.current_bet = player.put_in_this_round + amount
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
		# @return [Integer] The next seat to act 
		def next_seat(i = nil, times = 1, exclude_out = true)
			return unless times
			seat = i || self.current_player
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
			seat = i || self.current_player
			times.times do
				seat = seat - 1
				seat = (self.players.size - 1) if seat < 0
			end
			return seat
		end

		def cycle_seats(start = nil, exclude_out = true)
			start = self.current_player unless start
			seat = start
			first_seat = seat
			loop do
				yield self.players[seat], seat
				seat = next_seat(seat, 1, exclude_out)
				break if seat == first_seat
			end
			return nil
		end

		# @return [Integer] The seat number of the next dealer
		def next_dealer
			return next_notout_seat(self.dealer)
		end

		# @return [Integer] The number of active players between the dealer and the
		# current player
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

		# @return [Integer] The seat of the next player to act
		def next_player_to_act(i = nil)
			cycle_seats(i) do |player, idx|
				return idx if player.still_to_act?
			end
			return nil
		end

		# @return [Boolean] Is there enough cards to start the current stage?
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
			return self.players.select{|p| p.active?}
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
					player.last_action = nil
					player.acted = false
				end
				deal_cards
				self.current_player = next_player_to_act(first_to_act)
				stage_changed
			end
		end

		# Called when a player has just moved
		def player_moved
			# Record their move
			record_last_action
			# Send each player an event notification
			send_each_player(:player_moved)
		end

		# @return [Merlion::Player] The last player to act
		def last_player_to_act_obj
			return nil unless last_player_to_act
			players[last_player_to_act]
		end

		# Called after a player has finished acting. May change the stage or end
		# the hand if necessary, otherwise changes to next player
		def player_finished
			self.last_player_to_act = current_player
			player_moved

			# If there is only one player remaining in the game, they've won, so end the hand
			if num_active_players == 1
				return hand_finished
			end

			# If there are more players to act, make it their turn
			if (next_player = next_player_to_act(next_seat))
				self.current_player = next_player
			else
				# If there are no more players to act this round, but >1 still in the
				# game, progress to next stage
				next_stage
			end
		end

		# Records a single action for the last player's moved
		def record_last_action
			return unless self.stage_num
			act = last_player.last_action
			(self.current_hand_history[self.stage_num] ||= []).push(act)
		end

		# @return [Array] A list of actions for the current stage
		def stage_history
			return current_hand_history[stage_num]
		end

		def determine_winners
			# one winner, reward them
			winners = []
			if (num_active_players == 1)
				winner = self.players.find{|p| p.active?}
				winners.push([winner, self.pot])
			else
				winp = active_players.select{|p| !p.hole_cards.empty?}.group_by{|p| pe.score_hand(p.hole_str, board_str)}
				winp = winp.max.last
				give_each = self.pot / winp.size
				winners = winp.map{|w| [w, give_each]}
			end

			winners.each do |w|
				w[0].stack += w[1]
			end
			winners
		end

		# Called after a hand has finished to resolve the winner
		def hand_finished
			winners = determine_winners

			self.last_winners = winners

			# Log the game in the database
			record_hand_history

			# Send hand_finished notification
			send_each_player(:hand_finished)

			# Remove any players that have disconnected
			remove_quit_players

			finalize_hand
		end

		def finalize_hand
			# set next dealer. should this be moved to hand_started?
			if have_enough_players?
				self.dealer = next_dealer
			end

			self.stage_num = nil
		end

		# Sends event notifications to each player
		# @param sym [Symbol] The method name to call on each player
		def send_each_player(sym)
			players.each(&sym)
		end

		def flat_history
			actions = current_hand_history.flatten.map{|sym| action_to_db(sym).to_s}.join('')
			actions
		end

		# Record the game in the database. Saves the cards, player names, seats and amounts won
		# Should be enough to calculate a high score table, but also replay the games if needed
		def record_hand_history
			db.transaction do |db|
				actions = flat_history
				db.execute('insert into games(dealer, actions, small_blind, big_blind,
				pot, board_cards, table_id, table_name) values(?,?,?,?,?,?,?,?)', dealer, actions, small_blind,
				big_blind, pot, board_cards, table_id, name)
				game_id = db.last_insert_row_id
				players.each do |p|
					won = p.stack - p.starting_stack
					db.execute('insert into game_players(game_id, name, seat, hole_cards, won) values(?, ?, ?, ?, ?)', game_id, p.name, p.seat, p.hole_cards, won)
				end
			end
		end

		def set_initial_state!
		end

		# @return [String] The name of the current stage
		def stage
			begin
				return Stages[self.stage_num]
			rescue
				return :not_started
			end
		end

		# @return [Integer] The id of the current table
		def table_id
			object_id
		end

		# @return [Array] The board cards as an array
		def board_cards_ary
			return [] unless board_cards
			board_cards.scan(/../)
		end

		# Converts the game state to a hash, for example for sending as JSON
		def to_hash
			hash = {}
			hash[:stage] = stage
			hash[:pot] = pot
			hash[:current_player] = current_player
			hash[:cards] = board_cards_ary
			hash[:table_id] = table_id
			hash[:dealer] = dealer
			hash[:name] = name
			if (stage == :preflop)
				hash[:blinds] = has_posted_blinds?
			end
			return hash
		end

		# @return [Hash] The game state (including players) as a hash
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
