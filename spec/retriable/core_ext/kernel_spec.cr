require "../../spec_helper"
require "../../../src/retriable/core_ext/kernel"

describe Retriable::KernelExtension do
  it "can be called in the global scope" do
    tries = 0

    expect_raises(Exception) do
      retry times: 3 do
        tries += 1
        raise Exception.new
      end
    end
    tries.should eq 3
  end
end
