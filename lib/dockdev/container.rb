
require 'docker/cli'

module Dockdev
  class Container

    def initialize(name)
      @cont_name = name
      @cmd_fact = Docker::Cli::CommandFactory.new
    end

    def name
      @cont_name
    end

    def has_container?
      res = @cmd_fact.find_from_all_container(@cont_name, exact_name: true).run
      if res.success?
        not res.is_out_stream_empty?
      else
        raise Error, "Command find from all container failed with error : #{res.err_stream}"
      end
    end

    def running?
      res = @cmd_fact.find_running_container(@cont_name, exact_name: true).run 
      if res.success?
        not res.is_out_stream_empty?
      else
        raise Error, "Command to check is container running failed with error : #{res.err_stream}"
      end
    end

    def attach_and_exec(opts = {})
      optss = {
        tty: true,
        interactive: true
      }
      @cmd_fact.run_command_in_running_container(@cont_name, opts[:command], optss).run 
    end

    def start_with_command(opts = {})

      res = @cmd_fact.start_container(@cont_name).run 
      if res.success? and not res.is_out_stream_empty?
        attach_and_exec(opts)
      else
        raise Error, "Command to start container failed with error : #{res.err_stream}"
      end


    end

    def stop
      res = @cmd_fact.stop_container(@cont_name).run
      if res.success?
        not res.is_out_stream_empty?
      else
        raise Error, "Command stop container failed with error : #{res.err_stream}"
      end
    end

    def destroy
      res = @cmd_fact.delete_container(@cont_name).run
      if res.success?
        not res.is_out_stream_empty?
      else
        raise Error, "Command delete container failed with error : #{res.err_stream}"
      end
    end

  end
end
