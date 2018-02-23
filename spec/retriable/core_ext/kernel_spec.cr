require "../../spec_helper"
require "../../../src/retriable/core_ext/kernel"

describe Retriable::KernelExtension do
  it "#retry can be called in the global scope" do
    tries = 0

    expect_raises(Exception) do
      retry times: 3 do
        tries += 1
        raise Exception.new
      end
    end
    tries.should eq 3
  end

  context "#retry with no arguments" do
    it "retries given block" do
      tries = 0

      return_value = retry times: 10 do
        tries += 1
        next retry if tries < 5
        "finished"
      end
      return_value.should eq "finished"
      tries.should eq 5
    end
  end
end
