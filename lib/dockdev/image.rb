
require 'docker/cli'

module Dockdev
  class Image
    include TR::CondUtils

    def initialize(name)
      @image_name = name
      @cmd_fact = Docker::Cli::CommandFactory.new
    end

    def has_image?
      res = @cmd_fact.find_image(@image_name).run
      if res.success?
        not res.is_out_stream_empty?
      else
        raise Error, "Error triggered during find existing image : #{res.err_stream}"
      end
    end

    def new_container(cont_name, opts = {})
      optss = {
        interactive: true,
        tty: true,
        container_name: cont_name
      }
      optss.merge!(opts)
      @cmd_fact.create_container_from_image(@image_name, optss).run
    end

    def build(dockerfile, opts = {})
      optss = {  
        context_root: opts[:root],
        dockerfile: dockerfile
      }
      res = @cmd_fact.build_image(@image_name, optss).run
      if res.success? 
        new_container(opts[:container_name], opts)
      else
        raise Error, "Error triggered during find existing image : #{res.err_stream}"
      end
    end

  end
end
