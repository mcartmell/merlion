require 'merlion/lobby'
require 'merlion/lobby/connhelper'
require 'em-websocket'
require 'eventmachine'
require 'singleton'
require 'json'

class Merlion
	class Lobby
		class JSONClient
			include Merlion::Lobby::ConnHelper
			def get_games_list
				return lobby.get_games.to_json
			end
		end
		class WebSocketConnection < JSONClient
			def initialize(ws, lobby)
				@ws = ws
				@lobby = lobby
			end
			def write(msg)
				msg.encode!('UTF-8')
				@ws.send(msg)
			end	
		end
	end
end


class Merlion
	class Lobby
		class WebSocketServer
			include Singleton
			attr_reader :lobby

			def init(lobby)
				@lobby = lobby
				@ws_conns = {}
			end

			def start_server
				EM::WebSocket.start(:host => '0.0.0.0', :port => 11111) do |ws|
					ws.onopen do |handshake|
						@ws_conns[ws.object_id] = Merlion::Lobby::WebSocketConnection.new(ws, self.lobby)
					end
					ws.onmessage do |msg|
						obj = @ws_conns[ws.object_id]
						obj.handle(msg)
					end
				end
			end
		end
	end
end

