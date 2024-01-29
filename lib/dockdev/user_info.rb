
require 'etc'

module Dockdev
  module UserInfo
    include TR::CondUtils

    def self.user_info(login = nil)
      login = Etc.getlogin if is_empty?(login)
      res = { login: login }
      begin
        res[:uid] = Etc.getpwnam(login).uid
      rescue Exception => ex
        res[:uid] = nil
      end
      res
    end

    def self.group_info(login = nil)
      login = Etc.getlogin if is_empty?(login)
      res = {  }
      begin
        gnm = Etc.getgrnam(login)
        res[:group_name] = gnm.name
        res[:gid] = gnm.gid
      rescue Exception => ex
        p ex
        res[:group_name] = ""
        res[:gid] = nil
      end
      res
    end

  end
end

