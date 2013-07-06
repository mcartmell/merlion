require 'rspec'
require 'merlion/game'

describe Merlion::Game do
	it "Can be initialized" do
		m = Merlion::Game.new
		expect(m).to be_an_instance_of(Merlion::Game)
		m.initialize_from_opts({ num_players: 3, dealer: 0, stacks: [200,200,200]})
		expect(m.num_players).to eq(3)
		expect(m.players.size).to eq(3)
		m.players.each do |p|
			expect(p).to be_an_instance_of(Merlion::Player)
		end
		m.start_hand
		expect(m.stage).to eq(:preflop)
		expect(m.current_player).to eq(0)
		expect(m.players[1].put_in_this_round).to eq(m.small_blind)
		expect(m.players[2].put_in_this_round).to eq(m.big_blind)
		expect(m.players[0].put_in_this_round).to eq(0)
		m.act(:call)
		m.act(:call)
		m.act(:call)
		expect(m.stage).to eq(:flop)
	end

	it "Can play a game" do
		m = Merlion::Game.new
		m.initialize_from_opts({ num_players: 3, dealer: 0, stacks: [200,200,200]})
		m.start_hand
		expect(m.num_board_cards).to eq(0)
		m.act(:call)
		m.act(:call)
		m.act(:call)
		expect(m.num_board_cards).to eq(3)
		m.act(:call)
		m.act(:call)
		m.act(:call)
		expect(m.num_board_cards).to eq(4)
		m.act(:call)
		m.act(:call)
		m.act(:call)
		expect(m.num_board_cards).to eq(5)
		p m
		m.act(:call)
		m.act(:call)
		m.act(:call)
		expect(m.stage).to eq(:preflop)
	end

end
