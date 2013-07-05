require 'rspec'
require 'merlion/game'

describe Merlion::Game do
	it "Can be initialized" do
		m = Merlion::Game.new
		expect(m).to be_an_instance_of(Merlion::Game)
	end
end
