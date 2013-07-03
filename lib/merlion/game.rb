require 'merlion/player'
require 'merlion/bot'
require 'pokereval'

class Merlion
	class Game
		attr_accessor :small_blind, :big_blind, :num_players, :current_bet, :pot, :board_cards, :dealer, :stage_num, :current_player, :players, :last_player_to_act, :game_id
		attr_reader :stacks, :names, :meerkat_server, :meerkat

		Stages = [:preflop, :flop, :turn, :river, :game_finished]

		def initialize(opts = {})
		end
		
		def initialize_from_opts(opts = {})
			default = {
				meerkat: true,
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
				resolve_state
			end
		end

		def set_initial_state!
		end

		def create_player(index, type = Merlion::Player, name = nil)
			i = index
			opts = {stack: stacks[i], seat: i, game: self, name: (names || "Player #{i}")}
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

		def meerkat?
			@meerkat
		end

		def last_player
			players[last_player_to_act]
		end

		def start_hand
			self.stage_num = 0
			self.pot = 0
			self.current_bet = 0
			self.current_player = first_to_act
			self.last_player_to_act = nil
			players.each do |p|
				p.hand_started
			end
			act('small_blind')
			act('big_blind')
		end

		def process_acpc_line(line)
			if line[0] == '#'
				if line.chop == '#END_HAND'
					hand_finished
				end
			else
				return read_from_matchstate(line)
			end
			return false
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

		def read_from_matchstate(mstr)
			start_hand
			mstr.chomp!
			if (m = mstr.match(/MATCHSTATE:(\d+):(\d+):([^:]*):([^:]*)/))
				seats_from_dealer = m[1].to_i + 1
				self.set_bot_player(seats_from_dealer)
				self.game_id = m[2]
				betting = m[3]
				cards = m[4]

				# get cards first
				cards = cards.partition('/')
				hole_cards = cards[0]
				board_cards = cards[2]
				hole_cards.split('|').each_with_index do |elem, i|
					# index is seat relative to dealer
					pseat = next_notout_seat(@dealer, i + 1)
					player = @players[pseat]
					player.hole_cards = elem || ''
				end
				self.board_cards = board_cards.split('/').join('')

				# then process betting rounds
				betting.split(//).each do |action|
					method = case action
						when 'r'
							'raise!'
						when 'c'
							'call!'
						when 'f'
							'fold!'
						else
							nil
					end
					if method
						act(method)	
					end
				end
				if player_to_act.respond_to?(:get_action)
					player_to_act.get_action
				end

				players.each do |p|
					p.state_changed
				end
				#print_players

			end
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
				seat = 0 if seat > (@players.size - 1)
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
			self.last_player_to_act = current_player
			
			#puts "#{current_player} ACTED, NEXT SEAT IS #{next_seat}"
			if (next_player = next_player_to_act(next_seat))
				#puts "NEXT PLAYER IS #{next_player}"
				self.current_player = next_player
			else
				if num_active_players == 1
					hand_finished
				else
					next_stage
				end
			end
		end

		def has_got_enough_cards_for_stage?
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
		end

		def minimum_bet
			return (self.stage_num > 1 ? self.big_blind * 2 : self.big_blind)
		end
	end
end
