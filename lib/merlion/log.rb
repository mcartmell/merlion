require 'logger'
require 'colorize'
class Merlion
	module Log
		LogLevels = {
			"INFO" => "* ".light_green,
			"WARN" => "* ".light_cyan,
			"ERROR" => "* ".red,
			"FATAL" => "*** ".light_red,
			"DEBUG" => "* "
		}

		def self.log_formatter
			return proc do |level, datetime, progname, msg|
				(LogLevels[level] || '* ') + "#{msg}\n"
			end
		end

		def self.log
			return @log if @log
			@log = Logger.new(STDOUT)
			@log.level = Logger::INFO
			@log.formatter = log_formatter
			return @log
		end

		def log
			Merlion::Log.log
		end

		%w{info debug warn error fatal}.each do |level|
			define_method(level) do |msg|
				return log.send(level.to_sym, msg)
			end
		end

	end
end
