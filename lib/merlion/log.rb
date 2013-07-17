require 'logger'
require 'colorize'
class Merlion
	# A simple logging module
	module Log
		LogLevels = {
			"INFO" => "* ".light_green,
			"WARN" => "* ".light_cyan,
			"ERROR" => "* ".red,
			"FATAL" => "*** ".light_red,
			"DEBUG" => "* "
		}

		# Our log formatter
		def self.log_formatter
			return proc do |level, datetime, progname, msg|
				(LogLevels[level] || '* ') + "#{msg}\n"
			end
		end

		# Creates or returns the Logger instance
		def self.log
			return @log if @log
			@log = Logger.new(STDOUT)
			@log.level = ENV['MERLION_LOG_LEVEL'].to_i || Logger::INFO
			@log.formatter = log_formatter
			return @log
		end

		# Accessor for objects
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
