
require 'bundler'

module Dockdev
  module Context
    class Rubygems

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

      def process_mount(opts = { dir_inside_docker: "/opt" })

        if @mounts.empty?

          dir_inside_docker = opts[:dir_inside_docker]

          script = ["#!/bin/bash"]
          #script << "alias be > /dev/null 2>&1 && echo 'alias be=bundle exec' >> ~/.bashrc"
          script << "echo 'alias be=\"bundle exec\"' >> ~/.bashrc"

          # 
          # looking at source code 
          # https://github.com/rubygems/rubygems/blob/master/bundler/lib/bundler/shared_helpers.rb#L246
          # seems this is the way to set root for Bundler
          #
          ENV['BUNDLE_GEMFILE'] = find_gemfile.first
          Bundler.load.dependencies.each do |d|
            if not d.source.nil?
              src = d.source
              if src.path.to_s != "."
                pathInsideDocker = File.join(dir_inside_docker, d.name)
                @mounts[src.path.expand_path.to_s] = pathInsideDocker
                script << "bundle config --global local.#{d.name} #{pathInsideDocker}"
                #res[d.name] = src.path.expand_path.to_s
              end
            end
          end

          scriptOut = File.join(@path,"to-be-executed-once-inside-docker.sh") 
          File.open(scriptOut,"w") do |f|
            f.write script.join("\n")
          end
          `chmod +x #{scriptOut}`

        end

        @mounts

      end

      def process_port(opts = {})
        @ports
      end

    end
  end
end

Dockdev::Context::ContextManager.instance.register(:rubygems, Dockdev::Context::Rubygems)

