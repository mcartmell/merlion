require 'colorize'
class Merlion
	module Util
		ActionMap = {
			'f' => :fold,
			'c' => :call,
			'r' => :bet_raise,
			'k' => :check_or_fold
		}
		# When talking to the Meerkat bridge, 'f' is check or fold
		InvertedActionMap = ActionMap.invert
		InvertedActionMap.merge!({
			check_or_fold: 'f',
		})

		def render_cards(str)
			str.scan(/../).map do |cards|
				cards =~ /d|h/ ? cards.red.on_white : cards.black.on_white
			end.join('')
		end

		def action(str)
			act = ActionMap[str]
			unless act
				raise "Unknown action '#{str}'"
			end
			return act
		end

		def action_str(sym)
			act = InvertedActionMap[sym]
			unless act
				raise "Unknown action '#{sym}'"
			end
			return act
		end

	end
end
