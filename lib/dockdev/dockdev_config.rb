
require 'toolrack'

module Dockdev


  ## Support multiple Dockerfile different configurations
  ##   Default config is the default Dockerfile file name
  #class Configs
  #  include TR::CondUtils

  #  def initialize
  #    @configs = { default: Config.new }
  #  end

  #  def config_names
  #    @configs.keys.freeze
  #  end

  #  def default_config_name
  #    :default
  #  end

  #  def default_config
  #    @configs[:default]
  #  end

  #  def config(name)
  #    indx = File.basename(name)
  #    indx = :default if indx == "Dockerfile"

  #    conf = @configs[indx]
  #    if conf.nil?
  #      conf = Config.new 
  #      @configs[indx] = conf
  #    end
  #    conf
  #  end

  #  def is_config_exist?(name)
  #    not_empty?(config(name))
  #  end

  #  private
  #  def method_missing(mtd, *args, &block)
  #    default_config.send(mtd, *args, &block)
  #  end
  #end # end class Configs

  # Content of the config file 
  #   which shall configure the to be run docker instance
  #   Hence mostly the accessors/readers are related to docker configuration items
  class Config
    include TR::CondUtils

    # for image
    attr_accessor :workdir

    # for container
    attr_reader :mounts, :ports
    attr_accessor :network
    
    # for image
    attr_reader :dockerfile_entries

    # since context activation is automated:
    # 1. skip_context shall skip all found automated activated context
    # 2. activate_context shall add those context which is not found by automated discovery
    attr_reader :skip_context, :activate_context
    def initialize(val = {})
      @mounts = val[:mounts] || {}
      @ports = val[:ports] || {}
      @network = val[:network] || nil
      @dockerfile_entries = val[:dockerfile_entries] || []
      @workdir = val[:workdir] || "/opt"
      @skip_context = val[:skip_context] || []
      @activate_context = val[:activate_context] || []
    end


    # Convert internal value into hash to be written to file to get rid of the object 
    #   encoding in the yaml file
    def to_storage
      { mounts: @mounts, ports: @ports, dockerfile_entries: @dockerfile_entries, workdir: @workdir, skip_context: @skip_context, activate_context: @activate_context }
    end


    # Add mount mapping of host => docker follows docker-cli which follows
    #   docker cli -v format
    #
    # @param on_host [String] path on host
    # @param on_docker [String] path on docker
    # @param opts [Hash] options for the mount spec definition. Value keys including:
    # @option opts [Symbol] :duplicated_entry_policy :error (default) raise error if the on_host is duplicated/already defined
    # @option opts [Symbol] :duplicated_entry_policy :warn_replace raise warning if the on_host is duplicated/already defined and new entry shall replace the old entry
    # @option opts [Symbol] :duplicated_entry_policy :warn_discard raise warning if the on_host is duplicated/already defined and new entry is discarded
    def add_mount(on_host, on_docker, opts = { duplicated_entry_policy: :error })
      if not_empty?(on_host) and not_empty?(on_docker)
        if @mounts.keys.include?(on_host)
          policy = opts[:duplicated_entry_policy] || :error 
          case policy
          when :warn_replace
            logger.warn "on_host '#{on_host}' was mapped to '#{@mounts[on_host]}'. It shall be replaced with '#{on_docker}'"    
            @mounts[on_host] = on_docker 

          when :warn_discard
            logger.warn "on_host '#{on_host}' already mapped to '#{@mounts[on_host]}'. New value on_docker is ignored."    

          else
            # default policy always raise error
            raise Error, "on_host '#{on_host}' already mapped to '#{@mounts[on_host]}'"
          end
        else
          @mounts[on_host] = on_docker 
        end
      else
        logger.debug "add_mount unsuccessful = on_host : #{on_host} / on_docker : #{on_docker}"
        raise Error, "on_host mount entry cannot be empty" if is_empty?(on_host)
        raise Error, "on_docker mount entry cannot be empty" if is_empty?(on_docker)
      end
    end


    # Add port mapping of host => docker follows docker-cli which follows
    #   docker cli -p format
    #
    # @param on_host [String] port on host
    # @param on_docker [String] port on docker
    # @param opts [Hash] options for the port spec definition. Value keys including:
    # @option opts [Symbol] :duplicated_entry_policy :error (default) raise error if the on_host is duplicated/already defined
    # @option opts [Symbol] :duplicated_entry_policy :warn_replace raise warning if the on_host is duplicated/already defined and new entry shall replace the old entry
    # @option opts [Symbol] :duplicated_entry_policy :warn_discard raise warning if the on_host is duplicated/already defined and new entry is discarded
    def add_port(on_host, on_docker, opts = { duplicated_entry_policy: :error })
      if not_empty?(on_host) and not_empty?(on_docker)
        if @ports.keys.include?(on_host)
          policy = opts[:duplicated_entry_policy] || :error 
          case policy
          when :warn_replace
            logger.warn "on_host '#{on_host}' was mapped to '#{@mounts[on_host]}'. It shall be replaced with '#{on_docker}'"    
            @ports[on_host] = on_docker 

          when :warn_discard
            logger.warn "on_host '#{on_host}' already mapped to '#{@mounts[on_host]}'. New value on_docker is ignored."    

          else
            # default policy always raise error
            raise Error, "on_host '#{on_host}' already mapped to '#{@mounts[on_host]}'"
          end
        else
          @ports[on_host] = on_docker 
        end
      else
        logger.debug "add_port unsuccessful = on_host : #{on_host} / on_docker : #{on_docker}"
        raise Error, "on_host port entry cannot be empty" if is_empty?(on_host)
        raise Error, "on_docker port entry cannot be empty" if is_empty?(on_docker)
      end

    end

    # Any instruction to be appended into Dockerfile.
    #   Note this did not presume the entry is RUN, COPY or anyting. 
    #   A full valid Dockerfile entry has to be provided here
    #
    # @param st [String] Full valid Dockerfile line to be embed into Dockerfile
    def append_Dockerfile(st)
      logger.debug "Appending : #{st}"
      @dockerfile_entries << st
    end

    def is_context_should_skip?(name)
      @skip_context.include?(name)
    end


    def manual_activated_context
      @activate_context.freeze
    end


    private
    def logger
      Dockdev.logger(:config)
    end

    def has_additional_entries?
      not @dockerfile_entries.empty?
    end
  end

  # Managing the config
  class DockdevConfig
    include TR::CondUtils

    DOCDEV_CONFIG_FILE = "dockdev-config"

    def self.load(root = Dir.getwd, &block)
      confFile = Dir.glob(File.join(root,"#{DOCDEV_CONFIG_FILE}.*")).grep(/.yml|.yaml$/)
      if confFile.length > 1
        block.call(:found_more, contFile)
      elsif confFile.length == 0
        block.call(:not_found)
      else
        block.call(:found, confFile.first)
      end
    end

    def initialize(conf = nil)
      logger.debug "Given to initialize : #{conf}"
      if not_empty?(conf)
        @config = parse(conf)
      else
        @config = Config.new
      end
    end


    def save(root = Dir.getwd)
      path = File.join(root,"#{DOCDEV_CONFIG_FILE}.yml")
      File.open(path,"w") do |f|
        f.write YAML.dump(@config.to_storage)      
      end
      path
    end


    # Build the docker image by embedding additional entries into the Dockerfile. 
    #   This likely will need a temporary file to be created and it should be managed by
    #   this operation.
    #
    # @param [Dockdev::Image] image instance
    # @param [String] path to selected Dockerfile
    def build_image(image, dockerfile_path, opts = { root: Dir.getwd }, &block)

      if has_additional_entries?

        logger.debug "dockdev_config has additional entry for Dockerfile. Merging additional entries into Dockerfile"

        root = opts[:root] || Dir.getwd
        # make it static name so: 
        # 1. No file removal is required
        # 2. Allow debug on generated Dockerfile
        # 3. Replace Dockerfile on each run and only single Dockerfile is left on system
        # 4. Allow this temporary to be added to .gitignore
        tmpFile = File.join(root, "#{File.basename(dockerfile_path)}-dockdev")
        File.open(tmpFile,"w") do |f|
          found = false
          File.open(dockerfile_path,"r").each_line do |line|
            # detecting the CMD line if there is any
            if line =~ /^CMD/
              found = true
              # here we append the lines
              dockerfile_entries.each do |al|
                f.puts al
              end
              f.write line

            else
              f.write line

            end
          end

          if not found
            @dockerfile_entries.each do |al|
              f.puts al
            end
          end

        end

        image.build(tmpFile)

      else
        logger.debug "dockdev_config has no additional entry for Dockerfile. Proceed to build found Dockerfile"
        image.build(dockerfile_path)
      end

    end


    private
    def parse(conf)
      logger.debug "Given to parse : #{conf}"
      cont = File.read(conf) 
      val = YAML.unsafe_load(cont)
      Config.new(val)
    end

    def method_missing(mtd, *args, &block)
      logger.debug "method_missing '#{mtd}' / #{args}"
      @config.send(mtd, *args, &block)
    end

    def logger
      Dockdev.logger(:dockdev_config)
    end

  end
end


if $0 == __FILE__

  require_relative '../dockdev'

  c = Dockdev::DockdevConfig.new
  c.add_mount("/Users/chris/01.Workspaces/02.Code-Factory/08-Workspace/docker-cli","/opt/docker-cli")
  c.save
end


