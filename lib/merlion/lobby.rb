require 'eventmachine'
require 'merlion/game/local'
require 'merlion/log'

class Merlion
	class Lobby
		include Merlion::Log
		attr_accessor :games

		def initialize
			@games = []
		end

		def create_game
			game = Merlion::Game::Local.new({ num_players: 3, stacks: [200,200,200] })
			game.start
			return game
		end

		def add_player_to_game(game, conn)
			new_player = games[game].add_player
			# remember which player is on this connection
			conn.player = new_player
			# set the connection for the player, so they can write messages
			new_player.conn = conn
			# consider starting the hand
			games[game].player_added
		end

		def remove_player_from_game(game, conn)
			conn.player = nil
			games[game].remove_player
		end

		class Connection < EM::Connection
			include Merlion::Log

			def initialize(lobby)
				@lobby = lobby
			end

		end
		
		def start
			EventMachine.run do
				games[0] = create_game
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
