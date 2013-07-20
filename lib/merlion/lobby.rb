require 'eventmachine'
require 'merlion/game/local'
require 'merlion/log'
require 'merlion/bot'
require 'merlion/agent/callbot'
require 'merlion/config'

# A Poker server written in Ruby
class Merlion
	# Represents a poker 'lobby'. Consists of multiple games, and handles the adding/removing of players to these games.
	class Lobby
		include Merlion::Config
		include Merlion::Log
		attr_accessor :games

		# Constructor
		def initialize
			@games = {}
		end

			# Creates Game objects according to the config file. Also creates any Bot players if necessary and adds them to the game. Then it calls start, which begins the main_loop Fiber
		def create_games_from_config
			conf[:games].each do |settings|
				game = Merlion::Game::Local.new(settings)
				bot_players = settings[:bot_players]
				if bot_players.instance_of?(Hash)
					bot_players.each do |klass, count|
						count.downto(1) do |i|
							game.add_player({ class: eval(klass), name: "#{klass.gsub(/::/,'_')} #{i}" })
						end
					end
				else
					settings[:bot_players].downto(1) do |i|
						game.add_player({ class: Merlion::Bot, name: "Merlion #{i}"})
					end
				end
				game.start
				games[game.table_id] = game
			end
		end

		# @param game_id [Integer] The game id to add a player to
		# @param name [String] The nme of the player
		# @param conn [Merlion::Connection] The connection object to associate with this player
		def add_player_to_game(game_id, name, conn)
			game = games[game_id]
			unless game
				raise "Didn't find game #{game_id}"
			end
			opts = {}
			opts[:name] = name if name
			new_player = game.add_player(opts)
			# set the connection for the player, so they can write messages
			new_player.conn = conn
			# remember which player is on this connection
			conn.add_player(game, new_player)
			# consider starting the hand
			game.player_added
		end

		# Returns the list of games as a serializable structure
		# @return [Array[Hash]] The list of games
		def get_games
			games = []
			self.games.each do |id, game|
				games.push({
					id: id,
					players: game.num_seated_players,
					max_players: game.num_players,
					name: game.name,
					player_names: game.players.map(&:name)
				})
			end
			return games
		end

		# A superclass for EM::Connections
		class Connection < EM::Connection
			include Merlion::Log

			def initialize(lobby)
				@lobby = lobby
			end

		end
		
		# Starts the servers that listen for new connections
		def start
			# Start listening on various protocols: keyboard, telnet and websocket.
			# Players can use any of these.
			EventMachine.run do
				create_games_from_config
				EM.open_keyboard(Merlion::Lobby::KeyboardHandler, self)
				begin
					EventMachine.start_server("0.0.0.0", 10000, Merlion::Lobby::TelnetServer, self)
					Merlion::Lobby::WebSocketServer.instance.init(self)
					Merlion::Lobby::WebSocketServer.instance.start_server
				rescue
				end
				#EM.next_tick { tick }
			end
		end

		def tick 
			puts "tick"
			EM.next_tick { tick }
		end
	end
end

require 'merlion/lobby/textclient'
require 'merlion/lobby/jsonclient'
