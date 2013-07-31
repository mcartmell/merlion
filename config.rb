Merlion::ConfigFile = {
	games: [
		{
			num_players: 2, 
			min_players: 2,
			stack: 10000,
			bot_players: 1,
			name: "Merlion heads-up"
		},
		{
			num_players: 6, 
			min_players: 5,
			stack: 1000,
			bot_players: {
				'Merlion::Bot' => 3,
				'Merlion::SimpleBot' => 1,
			},
			name: "3 merlions 6-max"
		},
		{
			num_players: 10, 
			min_players: 6,
			stack: 1000,
			bot_players: 5,
			name: "5 merlions 10-max"
		},
		{
			num_players: 4,
			min_players: 3,
			stack: 1000,
			bot_players: {
				'Merlion::Bot' => 1,
				'Merlion::CallBot' => 3
			},
			name: "bench-callbot",
			enabled: false
		},
		{
			num_players: 4,
			min_players: 3,
			stack: 1000,
			bot_players: {
				'Merlion::Bot' => 1,
				'Merlion::CallBot' => 1,
				'Merlion::SimpleBot' => 1
			},
			name: "bench-basic",
			enabled: false
		},
		{
			num_players: 4,
			min_players: 4,
			stack: 1000,
			bot_players: {
				'Merlion::Bot' => 2,
				'Merlion::SimpleBot' => 2
			},
			name: "bench-2v2",
			enabled: false
		},
		{
			num_players: 6,
			min_players: 4,
			stack: 1000,
			bot_players: {
				'Merlion::BotNoAI' => 1,
				'Merlion::SimpleBot' => 1,
				'Merlion::CallBot' => 1,
				'Merlion::SimpleBotLoose' => 1,
				'Merlion::Bot' => 1,
			},
			name: "bench-multi3",
			enabled: true
		},
		{
			num_players: 2,
			min_players: 2,
			stack: 1000,
			bot_players: {
				'Merlion::Bot' => 1,
				'Merlion::FBSBot' => 1,
			},
			name: 'bench-hup',
			enabled: false
		},
		{
			num_players: 6,
			min_players: 6,
			stack: 1000,
			bot_players: {
				'Merlion::Bot' => 1,
				'Merlion::SimpleBot' => 5,
			},
			name: 'bench-sbot',
			enabled: false
		}
	]
}
