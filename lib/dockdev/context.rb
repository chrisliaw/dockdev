
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

      def registered_context
        @ctx.keys.freeze
      end

      def registered_context_by_name(name, path)
        ctx = @ctx[id]
        if not ctx.nil?
          ctx.init_path(path) 
        end

        ctx
      end

      def get_context(path)
        ctx = {}
        @ctx.each do |k, v|
          vv = v.init_path(path)
          if vv.is_context?
            #ctx << vv
            ctx[k] = vv
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

