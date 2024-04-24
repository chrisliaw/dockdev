

RSpec.describe "UserConfig" do

  it "parse input string" do
    st = "network=mynetwork;cmd=\"/bin/bash --login\""

    p Dockdev::UserConfig.new(st)
  end

end
