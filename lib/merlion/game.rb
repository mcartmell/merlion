require 'merlion/player'
require 'merlion/bot'
require 'merlion/log'
require 'pokereval'

class Merlion
	class Game
		include Merlion::Log
		attr_accessor :small_blind, :big_blind, :num_players, :current_bet, :pot, :board_cards, :dealer, :stage_num, :current_player, :players, :last_player_to_act, :game_id
		attr_reader :stacks, :names

		Stages = [:preflop, :flop, :turn, :river, :game_finished]
		ActionMap = {
			'f' => :fold,
			'c' => :call,
			'r' => :raise
		}

		def action(str)
			act = ActionMap[str]
			unless act
				raise "Unknown action '#{str}'"
			end
			return act
		end

		def action_str(sym)
			act = ActionMap.invert[sym]
			unless act
				raise "Unknown action '#{sym}'"
			end
			return act
		end
		
		def initialize_from_opts(opts = {})
			default = {
			}
			opts = default.merge(opts)

			@small_blind = opts[:small_blind] || 10
			@big_blind = opts[:big_blind] || 20
			@num_players = opts[:num_players]

			@current_player = 0

			@names = opts[:names] || []

			@stacks = opts[:stacks] || [10000] * @num_players
			@players = []

			create_players

			@dealer = opts[:dealer] || get_first_dealer
		end

		def create_players
			@num_players.times do |i|
				@players[i] = create_player(i)
			end
		end


		def main_loop
			set_initial_state!
			loop do
				move = get_next_move
				process_move(move)
			end
		end

		def set_initial_state!
		end

		def create_player(index, type = Merlion::Player, name = nil)
			i = index
			opts = {stack: stacks[i], seat: i, game: self, name: (names[i] || "Player #{i}")}
			return type.new(opts)
		end

		# clone this object, but clone the players too
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
			loop do
				dealer = prev_seat(dealer)
				break unless players[dealer].out?
			end
			return dealer
		end

		def last_player
			players[last_player_to_act]
		end

		def start_hand
			self.stage_num = 0
			self.pot = 0
			self.current_bet = 0
			self.current_player = first_to_act
			self.board_cards = nil
			self.last_player_to_act = nil
			players.each do |p|
				p.hand_started
			end
			act('small_blind')
			act('big_blind')
		end

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

		def all_cards_used
			return board_cards + (players.map{|p| p.hole_cards}.join(''))
		end

		def board_str
			board_cards
		end

		def num_board_cards
			return (board_cards.length / 2)
		end

		def first_to_act
			return heads_up? ? @dealer : next_notout_seat(@dealer)
		end

		def heads_up?
			return @num_players == 2
		end

		def process_move(action, *args)
			return if !player_to_act
			player_to_act.send(action.to_sym, *args)
			player_finished
			state_changed
		end

		def state_changed
			players.each do |p|
				p.state_changed
			end
			#print_players
		end

		def inspect
			"#{stage.to_s.upcase} [#{board_str}] [#{pot}] [#{current_bet} bet] [#{current_player} to go] (#{@players.map{|p| p.inspect}.join('|')})"
		end

		def stage
			return Stages[self.stage_num]
		end

		def put_in_pot(player, amount)
			@pot += amount
			player.stack -= amount
			if (player.put_in_this_round + amount > @current_bet)
				@current_bet = player.put_in_this_round + amount
			end
		end

		def player_to_act
			return nil if !self.current_player || num_active_players == 1 
			return self.players[self.current_player]
		end

		def next_notout_seat(i = nil, times = 1)
			return next_seat(i, times, true)
		end

		def next_seat(i = nil, times = 1, exclude_out = false)
			return unless times
			seat = i || @current_player
			count = 0
			loop do
				seat = seat + 1
				seat = 0 if seat > (num_players - 1)
				if exclude_out
					count += 1 unless players[seat].out?
				else
					count += 1
				end
				break if count == times
			end
			return seat
		end

		def prev_seat(i = nil, times = 1)
			seat = i || @current_player
			times.times do
				seat = seat - 1
				seat = (@players.size - 1) if seat < 0
			end
			return seat
		end

		def cycle_seats(start = nil)
			start = @current_player unless start
			seat = start
			first_seat = seat
			loop do
				yield @players[seat], seat
				seat = next_seat(seat)
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

		def player_finished
			debug("Player finished")
			self.last_player_to_act = current_player

			if num_active_players == 1
				return hand_finished
			end

			if (next_player = next_player_to_act(next_seat))
				self.current_player = next_player
			else
				next_stage
			end
		end

		def has_got_enough_cards_for_stage?
			return nil unless board_cards
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
				@current_player = next_player_to_act(first_to_act)
			end
		end

		def num_active_players
			return active_players.size
		end

		def active_players
			return @players.select{|p| p.active?}
		end

		def hand_finished
			pe = PokerEval.new
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

			# update game stack
			self.players.each do |p|
				p.game_stack = p.stack
			end

			# set next dealer
			self.dealer = next_dealer

			players.each do |p|
				p.hand_finished
			end

			start_hand
		end

		def minimum_bet
			return (self.stage_num > 1 ? self.big_blind * 2 : self.big_blind)
		end

		alias_method :act, :process_move
	end
end
