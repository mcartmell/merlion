require 'pp'
class Merlion
	require 'merlion/db'

	# A class for analyzing game history
	class Analyzer
		include Merlion::DB

		# Prints some statistics about a number of games
		# @param games [Array] The database rows
		def analyze_games(games)
			player_totals = {}
			num_hands = 0
			sb, bb = games[0]['small_blind'], games[0]['big_blind']
			games.each do |game|
				num_hands += 1
				db.execute("select * from game_players where game_id=?", game['id']) do |p|
					pl = (player_totals[p['name']] ||= {})
					pl[:total_score] ||= 0
					pl[:total_score] += p['won']
				end
			end
			player_totals.each do |name, tots|
				sbh = (tots[:total_score] / num_hands / bb)
				tots[:sbh] = sbh
			end
			puts "From #{num_hands} hands:"
			player_totals.sort_by{|k, v| v[:sbh]}.reverse.each do |name, v|
				puts "#{name}: #{v[:sbh]}"
			end
		end

		# Analyzes game results by a table's id
		def analyze_table(table_id)
			db.results_as_hash = true
			games = db.execute("select * from games where table_id=?", table_id)
			return analyze_games(games)
		end

		# Analyzes game results by a table's name
		def analyze_table_name(table_name)
			db.results_as_hash = true
			games = db.execute("select * from games where table_name=?", table_name)
			return analyze_games(games)
		end
	end
end
