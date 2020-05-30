require "../spec_helper"

describe Retriable::ExponentialBackoff do
  subject = Retriable::ExponentialBackoff

  opts = {
    random:        Random::PCG32.new(0_u64, 0_u64),
    base_interval: 0.5.seconds,
    max_interval:  1.minute,
    rand_factor:   0.5,
    multiplier:    1.5,
  }

  context "#randomize?" do
    it "returns true if @rand_factor is not 0" do
      subject.new(**opts).randomize?.should be_true
    end

    it "returns false if @rand_factor is 0" do
      subject.new(**opts.merge(rand_factor: 0.0)).randomize?.should be_false
    end
  end

  it "defaults to Random::DEFAULT" do
    subject.new(**opts.merge(random: nil)).random.should eq Random::DEFAULT
  end

  it "returns intervals as an Iterator(Time::Span)" do
    subject.new(**opts).intervals.should be_a Iterator(Time::Span)
  end

  it "generates 9 randomized intervals" do
    subject.new(**opts).intervals.first(9).to_a.should eq [
      0.269990973,
      0.625829950,
      1.412230693,
      1.267721605,
      2.126947612,
      2.319677195,
      4.328396888,
      12.721655737,
      10.447093827,
    ].map(&.seconds)
  end

  it "generates defined number of intervals" do
    subject.new(**opts).intervals.first(5).to_a.size.should eq 5
  end

  it "generates intervals with a defined base interval" do
    subject.new(**opts.merge(base_interval: 1.second)).intervals.first(3).to_a.should eq [
      0.557882507,
      1.174393868,
      1.925284514,
    ].map(&.seconds)
  end

  it "generates intervals with a defined multiplier" do
    subject.new(**opts.merge(multiplier: 1.0)).intervals.first(3).to_a.should eq [
      0.483722163,
      0.683962690,
      0.412072865,
    ].map(&.seconds)
  end

  it "generates intervals with a defined max interval" do
    subject.new(**opts.merge(max_interval: 1.second, rand_factor: 0.0)).intervals.first(3).to_a.should eq [
      0.5,
      0.75,
      1.0,
    ].map(&.seconds)
  end

  it "generates intervals with a defined rand_factor" do
    subject.new(**opts.merge(rand_factor: 0.2)).intervals.first(3).to_a.should eq [
      0.452179465,
      0.643305552,
      1.183364452,
    ].map(&.seconds)
  end

  it "generates 10 non-randomized intervals" do
    subject.new(**opts.merge(rand_factor: 0.0)).intervals.first(10).to_a.should eq [
      0.5,
      0.75,
      1.125,
      1.6875,
      2.53125,
      3.796875,
      5.6953125,
      8.54296875,
      12.814453125,
      19.2216796875,
    ].map(&.seconds)
  end

  it "always returns :max_interval for higher iteration numbers" do
    subject.new(**opts)
      .intervals
      .skip(100)
      .first(3)
      .to_a
      .should eq Array.new(3) { opts[:max_interval] }
  end
end
