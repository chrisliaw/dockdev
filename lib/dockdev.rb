# frozen_string_literal: true

require 'teLogger'
require 'toolrack'
require 'docker/cli'
require 'colorize'

require_relative "dockdev/version"

require_relative 'dockdev/workspace'
require_relative 'dockdev/image'
require_relative 'dockdev/container'

module Dockdev
  include TR::CondUtils

  class Error < StandardError; end
  # Your code goes here...

  def self.with_running_container(contName, opts = {})

    root = opts[:root]
    cmd = opts[:command]

    ctx = Dockdev::Context::ContextManager.instance.get_context(root)
    logger.debug("Found context : #{ctx}")

    cont = Container.new(contName)
    if cont.has_container?
      if cont.running?
        cont.attach_and_exec(command: cmd)
      else
        cont.start_with_command(command: cmd)
      end
    else
      img = Image.new(contName)
      ws = opts[:workspace] || root
      wss = Workspace.new(ws)
      if img.has_image?
        mount = { root => File.join("/opt",File.basename(root)) }
        if not ctx.nil?
          mount = ctx.process_mount(mount)
          logger.debug "Mount points by context : #{mount}"
        end

        img.new_container(cont.name, command: cmd, mounts: mount)
      elsif wss.has_dockerfile?
        img.build(wss.dockerfile)
        
        mount = { root => File.join("/opt",File.basename(root)) }
        if not ctx.nil?
          mount = ctx.process_mount(mount)
          logger.debug "Mount points by context : #{mount}"
        end

        img.new_container(cont.name, command: cmd) #, mounts: mount)
      else
        raise Error, "\n No image and no Dockerfile found to build the image found. Operation aborted. \n\n".red
      end
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
