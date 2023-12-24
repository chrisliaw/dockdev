

module Dockdev
  class Workspace

    def initialize(root = Dir.getwd)
      @root = root
    end

    def name
      File.dirname(@root)
    end

    def has_dockerfile?
      Dir.glob(File.join(@root,"Dockerfile")).length > 0
    end

    def dockerfile
      Dir.glob(File.join(@root,"Dockerfile")).first
    end

    def has_docker_compose?
      Dir.glob(File.join(@root,"docker-compose.yml")).length > 0
    end

  end
end
