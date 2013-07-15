require File.dirname(__FILE__)+'/../../config.rb'
require 'ostruct'
require 'pathname'
class Merlion
	module Config
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
