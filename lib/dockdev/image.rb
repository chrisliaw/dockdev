
require 'docker/cli'

require 'securerandom'

require_relative 'user_info'

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
        container_name: cont_name,
        match_user: TR::RTUtils.on_linux?
      }
      optss.merge!(opts)

      @cmd_fact.create_container_from_image(@image_name, optss).run

    end

    def build(dockerfile, opts = {})

      dockerfilePath = dockerfile
      if is_transfer_user?(opts)
        cont = append_transfer_user_in_dockerfile(dockerfile)
        dockerfilePath = generated_dockerfile
        File.open(dockerfilePath, "w") do |f|
          f.write cont
        end
      end

      optss = {  
        context_root: opts[:root],
        dockerfile: dockerfilePath
      }
      optss.merge!(opts)
      @cmd_fact.build_image(@image_name, optss).run

      FileUtils.rm(generated_dockerfile) if File.exist?(generated_dockerfile) and not is_keep_generated_dockerfile?

    end

    def destroy
      res = @cmd_fact.delete_image(@image_name).run
      if res.success?
        not res.is_out_stream_empty?
      else
        raise Error, "Error triggered during deleting image : #{res.err_stream}"
      end
    end


    private
    def logger
      Dockdev.logger(:dockdev_image)
    end

    def is_keep_generated_dockerfile?
      v =  ENV["DOCKDEV_KEEP_GENERATED_DOCKERFILE"]
      is_empty?(v) ? false : (v.downcase == "true") ? true : false
    end

    def generated_dockerfile
      "Dockerfile-dockdev"
    end

    def is_transfer_user?(opts = {})
      if TR::RTUtils.on_linux?
        true
      else
        (opts[:match_user].nil? || not_bool?(opts[:match_user])) ? false : opts[:match_user]
      end
    end

    def append_transfer_user_in_dockerfile(file)
      if File.exist?(file)
        logger.debug "Append transfer user in dockerfile '#{file}'"
        res = []
        cont = File.read(file)
        indx = cont =~ /CMD/
        if indx != nil 

          res << cont[0...indx] 
          res << transfer_user_command
          res << cont[indx..-1] 

        else

          res << cont
          res << transfer_user_command

        end

        res.join

      else
        ""
      end
    end

    def transfer_user_command

      ui = UserInfo.user_info
      gi = UserInfo.group_info

      res = []
      res << "RUN apt-get update && apt-get install -y sudo"
      res << "RUN groupadd -f -g #{gi[:gid]} #{gi[:group_name]} && useradd -u #{ui[:uid]} -g #{gi[:gid]} -m #{ui[:login]} && usermod -aG sudo #{ui[:login]} && echo '#{ui[:login]} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
      res << "USER #{ui[:login]}"
      res.join("\n")

    end

  end
end
