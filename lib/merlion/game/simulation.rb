require 'pp'
class Merlion
	class Game
		class Simulation < Merlion::Game
			include Merlion::Log
			attr_reader :wt_cache

			def initialize(*a)
				super
				@wt_cache = {}
			end

			def self.from_game_state(gs)
				this = self.new
				this.game_state = gs.duplicate
				this
			end

			# Run until game has finished
			def run_once(predictors)
				loop do
					move = get_next_move(predictors)
					process_move(move)
					break if stage_num == nil
				end
			end

			def randomize_cards(hero_seat, weight_tables)
				players.each do |p|
					next if p.seat == hero_seat
					p.hole_cards = get_representative_hand(weight_tables[p.seat])
				end
			end

			def get_next_move(predictors)
				return unless player_to_act
				pred = predictors[player_to_act.seat]
				move = act_triplet(pred.call(player_to_act))
				return move
			end

			def hand_finished
				determine_winners
				finalize_hand
			end

			def get_representative_hand(wt)
				wtprobs = wt_cache[wt.object_id]

				unless wtprobs
					puts "recalculating cache"
					tot = 0.0
					probs = []
					wt.each do |k, v|
						tot += v
						probs.push([k, tot])
					end
					wtprobs = [probs, tot]
					wt_cache[wt.object_id] = wtprobs
				end

				probs = wtprobs[0]
				tot = wtprobs[1]

				rnd = Random.rand(tot)
				last = nil
				probs.each do |e|
					if (rnd <= e[1])
						cards = e[0]
						str = pe.mask_to_str(cards)
						return str
					end
				end
			end

			def act_triplet(probs)
				tot = 0.0
				trip = probs.map{|e| tot += e; tot.to_f.round(3)}
				rnd = Random.rand(tot.to_f)
				return :check_or_fold if rnd <= trip[0]
				return :call if rnd <= trip[1]
				return :bet_raise
			end

			%w{deal_cards hand_finished}.map(&:to_sym).each do |method|
				mgmeth = Merlion::Game.instance_method(method)
				newmethod = (method.to_s + '_orig').to_sym
				define_method(newmethod) do
					mgmeth.bind(self).call
				end
			end

			def deal_cards
				deal_cards_orig
			end

			def have_enough_players?
				true
			end

			def num_players
				players.size
			end

			def record_hand_history
			end

			def send_each_player(*a)
			end
			def stage_changed
			end
			def state_changed
			end
			def hand_started
			end
		end
	end
end
