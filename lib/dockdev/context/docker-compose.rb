
require 'yaml'

require 'tty/prompt'

module Dockdev
  module Context
    class DockerCompose
      
      def self.init_path(path)
        DockerCompose.new(path)
      end

      def initialize(path)
        @path = path
        @parsed = false
        @mounts = {}
        @ports = {}
        @pmt = TTY::Prompt.new
      end

      def is_context?
        not find_docker_compose.empty?
      end

      def find_docker_compose
        Dir.glob(File.join(@path,"docker-compose.*")).grep(/\.(yml|yaml)$/)
      end

      def parse_docker_compose
        if not @parsed 
          fdc = find_docker_compose

          begin
            if not fdc.empty?
              load_dc = @pmt.yes?("\n docker-compose file found. Load config? ".magenta)  

              if not load_dc
                @parsed = true
                return [@mounts, @ports]
              end
            end

            if fdc.length > 1
              @selected = @pmt.multi_select(" Please select docker-compose file(s) to parse for running config : ".magenta) do |mn|
                fdc.each do |f|
                  mn.choice File.basename(f), f
                end
              end
            else
              @selected = fdc
            end

          rescue TTY::Reader::InputInterrupt
            # Ctrl-C is pressed... exit
            exit(-1)
          end

          @selected.each do |dcf|
            logger.debug " Processing docker-compose : #{dcf}"
            dcc = YAML.load(File.read(dcf))
            dcc.each do |k,v|
              next if k == "version"
              v.each do |kk,vv|
                vv.each do |kkk, vvv|
                  if kkk == "volumes"
                    vvv.each do |vs|
                      logger.debug "Extracting mount point from #{dcf} : #{vs}"
                      vvs = vs.split(":")
                      @mounts[File.expand_path(vvs[0])] = vvs[1]
                    end
                  elsif kkk == "ports"
                    vvv.each do |vs|
                      logger.debug "Extracting ports from #{dcf} : #{vs}"
                      ps = vs.split(":")
                      @ports[ps[0]] = ps[1]
                    end
                  end
                end
              end
            end
 
          end

          @parsed = true
        end

        [@mounts, @ports]
      end

      def process_mount(opts = {}, &block)
        mounts, _ = parse_docker_compose
        mounts
      end

      def process_port(opts = {}, &block)
        _, ports = parse_docker_compose
        ports
      end

      private
      def logger
        Dockdev.logger(:ctx_docker_compose)
      end

    end
  end
end

Dockdev::Context::ContextManager.instance.register(:docker_compose, Dockdev::Context::DockerCompose)

