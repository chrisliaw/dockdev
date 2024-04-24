
require 'bundler'

module Dockdev
  module Context
    class Rubygems
      include TR::CondUtils

      def self.init_path(path)
        Rubygems.new(path)
      end

      def initialize(path)
        @path = path
        @mounts = {}
        @ports = {}
      end

      def is_context?
        find_gemfile.length > 0
      end

      def find_gemfile
        Dir.glob(File.join(@path,"Gemfile"))
      end

      def apply_context(dockdev_config)
        ddConf = dockdev_config

        if not_empty?(ddConf)

          # 
          # looking at source code 
          # https://github.com/rubygems/rubygems/blob/master/bundler/lib/bundler/shared_helpers.rb#L246
          # seems this is the way to set root for Bundler
          #
          ENV['BUNDLE_GEMFILE'] = find_gemfile.first
          if not_empty?(ENV['BUNDLE_GEMFILE'])

            cmd = ["echo 'alias be = \"bundle exec\"' >> /etc/bash.bashrc"]

            Bundler.load.dependencies.each do |d|
              if not d.source.nil?
                src = d.source
                if src.path.to_s != "."
                  pathInsideDocker = File.join(ddConf.workdir, d.name)
                  ddConf.add_mount(src.path.expand_path.to_s,pathInsideDocker)
                  # following line assumed 'bundle' program already installed inside the image
                  cmd << "bundle config --global local.#{d.name} #{pathInsideDocker}"
                end
              end
            end

            if not_empty?(cmd)
            
              script = ["#!/bin/bash"]
              script << "if ! command -v bundle &> /dev/null"
              script << "  echo \"Command 'bundle' is available!\""
              script.concat(cmd.collect { |e| "  #{e}"})
              script << "then"
              script << "  echo \"Command 'bundle' not available\""
              #script << "   exit 1"
              script << "fi"

              File.open("rubygems_init.sh","w") do |f|
                f.write script.join("\n")
              end

              ddConf.append_Dockerfile("COPY rubygems_init.sh /tmp/rubygems_init.sh") 
              ddConf.append_Dockerfile("RUN chmod +x /tmp/rubygems_init.sh && /tmp/rubygems_init.sh") 
            end

          end

        end

        ddConf
      end

      #def process_mount(opts = { dir_inside_docker: "/opt" })

      #  if @mounts.empty?

      #    dir_inside_docker = opts[:dir_inside_docker]

      #    script = ["#!/bin/bash"]
      #    #script << "alias be > /dev/null 2>&1 && echo 'alias be=bundle exec' >> ~/.bashrc"
      #    script << "echo 'alias be=\"bundle exec\"' >> ~/.bashrc"

      #    # 
      #    # looking at source code 
      #    # https://github.com/rubygems/rubygems/blob/master/bundler/lib/bundler/shared_helpers.rb#L246
      #    # seems this is the way to set root for Bundler
      #    #
      #    ENV['BUNDLE_GEMFILE'] = find_gemfile.first
      #    Bundler.load.dependencies.each do |d|
      #      if not d.source.nil?
      #        src = d.source
      #        if src.path.to_s != "."
      #          pathInsideDocker = File.join(dir_inside_docker, d.name)
      #          @mounts[src.path.expand_path.to_s] = pathInsideDocker
      #          script << "bundle config --global local.#{d.name} #{pathInsideDocker}"
      #          #res[d.name] = src.path.expand_path.to_s
      #        end
      #      end
      #    end

      #    scriptOut = File.join(@path,"to-be-executed-once-inside-docker.sh") 
      #    File.open(scriptOut,"w") do |f|
      #      f.write script.join("\n")
      #    end
      #    `chmod +x #{scriptOut}`

      #  end

      #  @mounts

      #end

      #def process_port(opts = {})
      #  @ports
      #end

    end
  end
end

Dockdev::Context::ContextManager.instance.register(:rubygems, Dockdev::Context::Rubygems)

