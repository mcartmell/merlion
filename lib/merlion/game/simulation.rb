require 'pp'
class Merlion
	class Game
		class Simulation < Merlion::Game
			include Merlion::Log
			include Merlion::Config
			attr_reader :wt_cache

			def initialize(*a)
				super
				@wt_cache = {}
        @ehs_cache = {}
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

			def randomize_cards(hero_seat, weight_tables, opts={})
				players.each do |p|
					next if p.seat == hero_seat
					p.hole_cards = get_representative_hand(weight_tables[p.seat], opts)
				end
			end

			def get_next_move(predictors)
				return unless player_to_act
				pred = predictors[player_to_act.seat]
				move = act_triplet(pred.call(player_to_act))
				return move
			end

			def hand_finished
				determine_winners.each do |w|
          #puts "[SIMUL] #{w[0].name} wins $#{w[1]} with #{w[0].hand_type}".light_white
        end
				finalize_hand
			end

			def get_representative_hand(wt, opts)
				wtprobs = wt_cache[wt.object_id]

				unless wtprobs
          wt_sorted = if opts[:sorted]
            # sort by best hands
            wt.each.sort_by do |k, v|
              # cache the ehs of these cards on this board
              @ehs_cache["#{k}-#{board_str}"] ||= pe.str_to_hs(pe.mask_to_str(k), board_str)
            end.drop(wt.size * config.simulation_fear)
          else
            wt.sort.drop(wt.size * config.simulation_fear)
          end

          puts "most likely hands:" + (wt_sorted.sort_by{|e| e[1]}.reverse.take(10).map do |k, v|
            pe.mask_to_str(k) + "(#{v.round(2)})"
          end.join(", "))
          puts "actual best hands:" + (wt_sorted.reverse.take(10).map do |k, v|
            pe.mask_to_str(k) + "(#{v.round(2)})"
          end.join(", "))

					# sort by most likely hands
          #wt_sorted = wt_sorted.drop(wt.size * config.simulation_fear)
					tot = 0.0
					probs = []
					wt_sorted.each do |k, v|
						tot += v
						probs.push([k, tot])
					end
					wtprobs = [probs, tot]
					wt_cache[wt.object_id] = wtprobs
				end

				probs = wtprobs[0]
				tot = wtprobs[1]

				unless tot > 0
					cards = probs.shuffle.first
					card_str = pe.mask_to_str(cards[0])
          return card_str
				end

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

      def info(*args)
      end
      def debug(*args)
      end
		end
	end
end
