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
  class Error < StandardError; end
  # Your code goes here...

  def self.with_running_container(contName, opts = {})

    root = opts[:root]
    cmd = opts[:command]
    cont = Container.new(contName)
    if cont.has_container?
      if cont.running?
        cont.attach_and_exec(command: cmd)
      else
        cont.start_with_command(command: cmd)
      end
    else
      img = Image.new(contName)
      ws = opts[:workspace] || Dir.getwd
      wss = Workspace.new(ws)
      if img.has_image?
        img.new_container(cont.name, command: cmd)
      elsif wss.has_dockerfile?
        img.build(wss.dockerfile)
        img.new_container(cont.name, command: cmd)
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

end
