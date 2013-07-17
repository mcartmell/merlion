require 'eventmachine'
require 'merlion/lobby'
require 'merlion/lobby/connhelper'

class Merlion
	class Lobby
		# A text client, eg. telnet/keyboard
		class TextClient < Merlion::Lobby::Connection
			include Merlion::Lobby::ConnHelper
			def write(msg, channel)
				send_data(msg)
			end
		end
	end
end

class Merlion
	class Lobby
		# A plain TCP client
		class TelnetServer < Merlion::Lobby::TextClient
			# Called when data has been received
			def receive_data(data)
				handle(data)
			end
		end
	end
end

class Merlion
	class Lobby
		# A keyboard client
		class KeyboardHandler < Merlion::Lobby::TextClient
			include EM::Protocols::LineText2

			# Called when a line has been received
			def receive_line(data)
				handle(data)
			end

			# Writes data to the scren
			def send_data(data)
				puts data
			end
		end
	end
end
