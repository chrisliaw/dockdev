

module Dockdev
  class UserConfig
    include TR::CondUtils

    def initialize(conf)
      @res = parse(conf)
    end

    def is_valid?
      @valid 
    end

    def method_missing(mtd, *args, &block)
      if has_key?(mtd)
        @res[mtd.to_sym]
      else
        nil
        #super
      end
    end

    def has_key?(key)
      @res.keys.include?(key.to_sym)
    end

    private
    def parse(conf)
      res = {}
      if conf.is_a?(String)      
        @valid = true
        conf.split(";").each do |v|
          vv = v.split("=")
          res[vv[0].to_sym] = vv[1] if not_empty?(vv[0]) and not_empty?(vv[1])
        end
      else
        @valid = false
      end

      res
    end
  end
end
