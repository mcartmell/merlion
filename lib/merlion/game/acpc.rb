class Merlion
	class Game
		class ACPC < Merlion::Game

			attr_reader :socket
			attr_reader :bot_player
			attr_accessor :bot_seat

			def initialize(opts = {})
				super
				server = opts[:server]
				port = opts[:port]
				@socket = TCPSocket.new server, port
			end

			def set_initial_state!
				defaults = {
				}
				opts = read_initial_state
				opts = defaults.merge(opts)
				bot_seat = opts[:bot_seat]
				set_bot_player(bot_seat)
				initialize_from_opts(opts)
				start_hand
			end

			def bot_player
				return unless bot_seat
				return players[bot_seat]
			end

			def set_bot_player(seats_from_dealer)
				return if @bot_seat # already set
				@bot_seat = next_seat(@dealer, seats_from_dealer, true)
				players[@bot_seat] = create_player(@bot_seat, Merlion::Bot)
			end

			def bot_seat
				return @bot_seat
			end

			def read_initial_state
				loop do
					line = socket.gets
					if m = line.match(/INITIAL_STATE:(.+)$/)
						state = m[1]
						(num_players,small_blind,big_blind,bot_seat,*rest) = state.split(',')
						stacks = rest.take(num_players).map{|e| e.to_i}
						names = rest.drop(num_players)
						return {
							num_players: num_players.to_i,
							small_blind: small_blind.to_f,
							big_blind: big_blind.to_f,
							bot_seat: bot_seat.to_i,
							stacks: stacks,
							names: names
						}
						break	
					end
				end
			end

			def create_players
				num_players.times do |i|
					player_class = (i == bot_player ? Merlion::Bot : Merlion::Player::ACPC)
					@players[i] = create_player(i, player_class)
				end
			end

			def get_next_move
				if player_to_act.respond_to?(get_move)
					# get the move, write it to the server and continue reading the gamestate
					move = player_to_act.get_move
					@socket.puts move
				end
				return read_next_move
			end

			def read_next_move
				ms = read_acpc_matchstate
				return ms[:last_action]
			end

			def read_acpc_matchstate
				interpret_acpc_matchstate(@socket.gets)
			end

			def interpret_acpc_matchstate(mstr)
				if (m = mstr.match(/MATCHSTATE:(\d+):(\d+):([^:]*):([^:]*)/))
					seats_from_dealer = m[1].to_i + 1
					game_id = m[2]
					betting = m[3]
					cards = m[4]

					# get cards first
					cards = cards.partition('/')
					hole_cards = cards[0]
					board_cards = cards[2]

					# deal out the cards
					hole_cards.split('|').each_with_index do |elem, i|
						# index is seat relative to dealer
						pseat = next_notout_seat(@dealer, i + 1)
						player = @players[pseat]
						player.hole_cards = elem || ''
					end
					self.board_cards = board_cards.split('/').join('')

					# then process betting rounds
					last_action = betting.last

					return {
						game_id: game_id,
						betting: betting,
						last_action: last_action,
						seats_from_dealer: seats_from_dealer
					}
				end
			end

			def hand_finished
				loop do
					line = @socket.gets
					interpret_acpc_matchstate(line) # update cards and things
					if line.chop == '#END_HAND'
						# now the hand has really finished
						super
						break
					end
				end
			end
		end
	end
end
