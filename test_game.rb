{
	simulation_fear: 0.4,
	games: [
		{
      max_hands: 250,
			num_players: 3, 
			min_players: 2,
			stack: 10000,
			name: "Merlion heads-up",
			bot_players: {
				'Merlion::Bot' => 1,
#				'Merlion::FBSBot' => 1,
				'Merlion::SimpleBot' => 1
			},
			name: "bench-simplebot",
			enabled: true
		},
	]
}
