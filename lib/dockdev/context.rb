
require 'singleton'

module Dockdev
  module Context
    class ContextManager
      include Singleton 

      def initialize
        @ctx = {}  
      end

      def register(name, cls)
        @ctx[name] = cls
      end

      def get_context(path)
        ctx = nil
        @ctx.values.each do |v|
          vv = v.init_path(path)
          if vv.is_context?
            ctx = vv
            break
          end
        end
        ctx
      end

    end
  end
end

Dockdev.logger.debug File.join(File.dirname(__FILE__),"context","*.rb")
Dir.glob(File.join(File.dirname(__FILE__),"context","*.rb")).each do |f|
  require f
end

