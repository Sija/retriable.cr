require "../spec_helper"

describe Retriable::Settings do
  settings = Retriable::Settings.new

  it "sleep defaults to enabled" do
    settings.sleep_disabled?.should be_false
  end

  it "max_attempts defaults to nil" do
    settings.max_attempts.should be_nil
  end

  it "max interval defaults to 1 minute" do
    settings.max_interval.should eq 1.minute
  end

  it "randomization factor defaults to 0.5 seconds" do
    settings.base_interval.should eq 0.5.seconds
  end

  it "multiplier defaults to 1.5" do
    settings.multiplier.should eq 1.5
  end

  it "max elapsed time defaults to 15 minutes" do
    settings.max_elapsed_time.should eq 15.minutes
  end

  it "intervals defaults to nil" do
    settings.intervals.should be_nil
  end

  it "on defaults to nil" do
    settings.on.should be_nil
  end

  it "on retry handler defaults to nil" do
    settings.on_retry.should be_nil
  end
end
