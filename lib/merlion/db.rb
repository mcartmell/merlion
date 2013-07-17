require 'sqlite3'
require 'merlion/config'

class Merlion
	# A generic DB module and mixin. Currently uses a SQLite3 database in db/games.db
	module DB
		include Merlion::Config
		# Returns the database instance
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
