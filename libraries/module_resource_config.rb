module WpCli
  module ResourceConfig

    def config(new_conf=nil)
      set_or_return(
        :config,
        new_conf,
        :kind_of => Hash
      )
      @config = validate_config(default_config) if @config.nil?
      @config = validate_config(default_config.merge(@config)) if new_conf
      @config
    end

    alias :args :config

    def default_config
      {}
    end

    def validate_config(conf)
      conf
    end

  end
end