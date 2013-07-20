CREATE TABLE game_players(id integer primary key, game_id integer, name string, seat integer, hole_cards string, won real, FOREIGN KEY(game_id) REFERENCES games(id) ON DELETE CASCADE);
CREATE TABLE games(id integer primary key, dealer integer, actions text, small_blind real, big_blind real, pot real, board_cards text, table_id text, table_name text);
CREATE INDEX game_id_idx ON game_players (game_id);
CREATE INDEX idx_tid ON games(table_id);
CREATE INDEX idx_tname ON games(table_name);
