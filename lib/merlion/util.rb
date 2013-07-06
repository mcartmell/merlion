require 'colorize'
class Merlion
	module Util
		def render_cards(str)
			str.scan(/../).map do |cards|
				cards =~ /d|h/ ? cards.red.on_white : cards.black.on_white
			end.join('')
		end
	end
end
