require File.dirname(__FILE__)+'/../../config.rb'
require 'ostruct'
require 'pathname'
class Merlion
	# A generic config module
	module Config
		# Returns the config as an OpenStruct. Loaded only once, on startup
		def self.config
			return @config if @config
			@config = Merlion::ConfigFile
			@config[:root_dir] = Pathname.new(File.dirname(__FILE__)).parent.parent.to_s
			@config = OpenStruct.new(@config)
			return @config
		end

		def config
			Merlion::Config.config
		end

		alias_method :conf, :config
	end
end
