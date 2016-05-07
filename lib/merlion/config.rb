require 'ostruct'
require 'pathname'
class Merlion
	# A generic config module
	module Config
    def self.config
      @config
    end

    def self.read(config_file=nil)
      config_file ||= File.dirname(__FILE__)+'/../../config.rb'
      config = eval(File.read(config_file))
			config[:root_dir] = Pathname.new(File.dirname(__FILE__)).parent.parent.to_s
			config = OpenStruct.new(config)
      @config = config
    end

    def config
      Merlion::Config.config
    end
	end
end
