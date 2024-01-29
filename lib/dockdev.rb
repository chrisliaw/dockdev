# frozen_string_literal: true

require 'teLogger'
require 'toolrack'
require 'docker/cli'
require 'colorize'

require 'tty/prompt'

require_relative "dockdev/version"

require_relative 'dockdev/workspace'
require_relative 'dockdev/image'
require_relative 'dockdev/container'

require_relative 'dockdev/dockdev_config'

module Dockdev
  include TR::CondUtils

  class Error < StandardError; end
  # Your code goes here...

  # main entry points to start docker
  def self.with_running_container(contName, opts = {})

    pmt = TTY::Prompt.new
    root = opts[:root]
    cmd = opts[:command]

    ddConf = load_config(root)

    cont = Container.new(contName)
    if cont.has_container?
      
      logger.debug "Container '#{contName}' already exist. Just run the container"
      if cont.running?
        cont.attach_and_exec(command: cmd)
      else
        cont.start_with_command(command: cmd)
      end

    else
      
      logger.debug "Container '#{contName}' does not exist. Creating the container"

      img = Image.new(contName)
      ws = opts[:workspace] || root
      wss = Workspace.new(ws)

      # root directory is mounted by default
      ddConf.add_mount(root, File.join(ddConf.workdir,File.basename(root)))

      ctx = Dockdev::Context::ContextManager.instance.get_context(root)
      logger.debug("Found context : #{ctx}")

      ctx.each do |name, cctx|

        if ddConf.is_context_should_skip?(name)
          logger.debug "Context '#{name}' is asked to be skipped"
          next
        end

        logger.debug "Appying context '#{name}' "
        # here allow context to add additional Dockerfile entries, mounts and ports
        ddConf = cctx.apply_context(ddConf)
      end

      ddConf.manual_activated_context.each do |cctx|
        mctx = Dockdev::Context::ContextManager.instance.registered_context_by_name(cctx)
        logger.debug "Executing manual activated context : #{mctx}"
        ddConf = mctx.apply_context(ddConf) if not mctx.nil?
      end

      if not img.has_image? 

        if wss.has_dockerfile?

          if wss.has_multiple_dockerfiles?

            selDockerFile = pmt.select("Please select one of the Dockerfile to proceed : ") do |m|
              wss.dockerfiles.each do |df|
                m.choice File.basename(df), df
              end
            end

          else
            selDockerFile = wss.dockerfile
          end

          # Delegated to config file to allow
          # config file to embed addtional entries (if there is any) and proceed to build it.
          # During the process it is very likey a temporary Dockerfile shall be created since 
          # docker cli works on file basis and this temporary file need to be managed after the process.
          # Hence this makes more sense to let the config handle all those inside the operation
          res = ddConf.build_image(img, selDockerFile, root: root) 
          raise Error, "Image failed to be built. Error was : #{res.err_stream}" if res.failed?
          STDOUT.puts "\n Image '#{contName}' built successfully\n\n".green
          #img.build(wss.dockerfile)

        else
          raise Error, "\n No image and no Dockerfile found to build the image. Operation aborted. \n\n".red

        end
      end

      # image already exist!
      # Since reach here means container doesn't exist yet.
      # Proceed to create container

      param = { command: cmd, mounts: ddConf.mounts, ports: ddConf.ports }
      img.new_container(cont.name, param)

      #if img.has_image?
      #  
      #  # has image but no container
      #  ctx.each do |cctx|
      #   
      #    ddConf = cctx.apply_context(ddConf)

      #    #cctx.process_mount(dir_inside_docker: ddConf.workdir).each do |host,docker|
      #    #  logger.debug "Mount points by context '#{cctx}' : #{host} => #{docker}"
      #    #  ddConf.add_mount(host, docker)
      #    #end

      #    #cctx.process_port.each do |host, docker|
      #    #  logger.debug "Ports mapping by context '#{cctx}' : #{host} => #{docker}"
      #    #  ddConf.add_port(host, docker)
      #    #end

      #    #mnts = cctx.process_mount(dir_inside_docker: ddConf.workdir)
      #    #logger.debug "Mount points by context : #{mnts}"

      #    #mount.merge!(mnts) if not mnts.empty?

      #    #prt = cctx.process_port
      #    #port.merge!(prt) if not prt.empty?

      #    #logger.debug "Ports by context #{cctx} : #{prt}"
      #  end

      #  #param = { command: cmd, mounts: mount }
      #  #param[:ports] = port if not port.empty? 
      #  param = { command: cmd, mounts: ddConf.mounts, ports: ddConf.ports }

      #  img.new_container(cont.name, param)

      #elsif wss.has_dockerfile?

      #  logger.debug "Dockerfile '#{wss.dockerfile}' found. Proceed building the image."

      #  # Delegated to config file to allow
      #  # config file to embed addtional entries (if there is any) and proceed to build it.
      #  # During the process it is very likey a temporary Dockerfile shall be created since 
      #  # docker cli works on file basis and this temporary file need to be managed after the process.
      #  # Hence this makes more sense to let the config handle all those inside the operation
      #  ddConf.build_image(img, wss, root: root)
      #  #img.build(wss.dockerfile)
      # 
      #  ddConf.add_mount(root, File.join(ddConf.workdir,File.basename(root)))
      #  #mount = { root => File.join(ddConf.workdir,File.basename(root)) }
      #  #port = {}
      #  ctx.each do |cctx|

      #    ddConf = cctx.apply_context(ddConf)

      #    #cctx.process_mount(dir_inside_docker: ddConf.workdir).each do |host,docker|
      #    #  logger.debug "Mount points by context '#{cctx}' : #{host} => #{docker}"
      #    #  ddConf.add_mount(host, docker)
      #    #end

      #    #cctx.process_port.each do |host, docker|
      #    #  logger.debug "Ports mapping by context '#{cctx}' : #{host} => #{docker}"
      #    #  ddConf.add_port(host, docker)
      #    #end

      #    #mnt = cctx.process_mount(dir_inside_docker: ddConf.workdir)
      #    #mount.merge!(mnt) if not mnt.empty?

      #    #logger.debug "Mount points by context #{cctx} : #{mnt}"

      #    #prt = cctx.process_port
      #    #port.merge!(prt) if not prt.empty?

      #    #logger.debug "Ports by context #{cctx} : #{prt}"
      #  end

      #  #param = { command: cmd, mounts: mount }
      #  #param[:ports] = port if not port.empty? 
      #  param = { command: cmd, mounts: ddConf.mounts, ports: ddConf.ports }

      #  img.new_container(cont.name, param)

      #else
      #  raise Error, "\n No image and no Dockerfile found to build the image found. Operation aborted. \n\n".red
      #end
    end
  end

  def self.destroy(contName, opts = {})

    cont = Container.new(contName)
    if cont.has_container?
      cont.stop if cont.running?
      cont.destroy
    end

    img = Image.new(contName)
    if img.has_image?
      img.destroy
    end

  end

  # detect if the additional configuration file exist
  def self.load_config(root)
 
    ddConf = DockdevConfig.new
    DockdevConfig.load(root) do |ops, *args|
      case ops
      when :found_more
        found = args.first
        pmt = TTY::Prompt.new
        selConf = pmt.select("There are more config files found. Please select one of the files below :") do |m|
          found.each do |f|
            m.choice Pathname.new(f).relative_path_from(root),f
          end
        end
        ddConf = DockdevConfig.new(selConf)
      when :found
        ddConf = DockdevConfig.new(args.first)
      else
      logger.debug "Load config got ops : #{ops}"
      end
    end

    logger.debug "Loaded config : #{ddConf}"
    ddConf
    
  end

  def self.logger(tag = nil, &block)
    if @_logger.nil?
      @_logger = TeLogger::Tlogger.new(STDOUT)
    end

    if block
      if not_empty?(tag)
        @_logger.with_tag(tag, &block)
      else
        @_logger.with_tag(@_logger.tag, &block)
      end
    else
      if is_empty?(tag)
        @_logger.tag = :dockdev
        @_logger
      else
        # no block but tag is given? hmm
        @_logger.tag = tag
        @_logger
      end
    end
  end

end

require_relative 'dockdev/context'
