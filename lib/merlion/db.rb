require 'sqlite3'
require 'merlion/config'

class Merlion
	module DB
		include Merlion::Config
		def self.db
			return @db if @db
			path = Merlion::Config.config[:root_dir] + '/db/games.db'
			@db = SQLite3::Database.new(path)
		end

		def db
			Merlion::DB.db
		end
	end
end
