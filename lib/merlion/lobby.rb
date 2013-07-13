require 'eventmachine'
require 'merlion/game/local'
require 'merlion/log'
require 'merlion/bot'

class Merlion
	require File.dirname(__FILE__)+'/../../config.rb'
	# Represents a poker 'lobby'. Consists of multiple games, and handles the adding/removing of players to these games.
	class Lobby
		include Merlion::Log
		attr_accessor :games

		def initialize
			@games = {}
		end

		def conf
			Merlion::Config
		end

		def create_games_from_config
			conf[:games].each do |settings|
				game = Merlion::Game::Local.new(settings)
				settings[:bot_players].downto(1) do |i|
					game.add_player({ class: Merlion::Bot, name: "Merlion #{i}"})
				end
				game.start
				games[game.table_id] = game
			end
		end

		def add_player_to_game(game_id, conn)
			game = games[game_id]
			unless game
				raise "Didn't find game #{game_id}"
			end
			new_player = game.add_player
			# set the connection for the player, so they can write messages
			new_player.conn = conn
			# remember which player is on this connection
			conn.add_player(game, new_player)
			# consider starting the hand
			game.player_added
		end

		def get_games
			games = []
			self.games.each do |id, game|
				games.push({
					id: id,
					players: game.num_seated_players,
					max_players: game.num_players,
					name: game.name
				})
			end
			return games
		end

		class Connection < EM::Connection
			include Merlion::Log

			def initialize(lobby)
				@lobby = lobby
			end

		end
		
		def start
			# Start listening on various protocols: keyboard, telnet and websocket.
			# Players can use any of these.
			EventMachine.run do
				create_games_from_config
				EventMachine.start_server("0.0.0.0", 10000, Merlion::Lobby::TelnetServer, self)
				EM.open_keyboard(Merlion::Lobby::KeyboardHandler, self)
				Merlion::Lobby::WebSocketServer.instance.init(self)
				Merlion::Lobby::WebSocketServer.instance.start_server
			end
		end
	end
end

require 'merlion/lobby/textclient'
require 'merlion/lobby/jsonclient'
