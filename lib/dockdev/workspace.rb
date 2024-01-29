

module Dockdev
  class Workspace

    def initialize(root = Dir.getwd)
      @root = root
    end

    def name
      File.dirname(@root)
    end

    def has_dockerfile?
      found_dockerfile_count > 0
    end

    def found_dockerfile_count
      dockerfiles.length 
    end

    def has_multiple_dockerfiles?
      found_dockerfile_count > 1
    end

    def dockerfiles
      Dir.glob(File.join(@root,"Dockerfile*"))
    end

    def dockerfile
      if has_dockerfile?
        dockerfiles.first
      else
        nil
      end
    end

    def has_docker_compose?
      Dir.glob(File.join(@root,"docker-compose.yml")).length > 0
    end

  end
end
