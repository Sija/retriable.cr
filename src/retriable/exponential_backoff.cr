module Retriable
  struct ExponentialBackoff
    property base_interval : Time::Span
    property max_interval : Time::Span
    property rand_factor : Float64
    property multiplier : Float64
    property random : Random { Random::DEFAULT }

    def initialize(@base_interval, @max_interval, @rand_factor, @multiplier, @random)
    end

    def intervals : Iterator(Time::Span)
      randomize? = !@rand_factor.zero?
      (0..Int32::MAX).each.map do |iteration|
        interval = {@base_interval * @multiplier**iteration, @max_interval}.min
        interval = randomize? ? randomize(interval) : interval
      end
    end

    protected def randomize(interval) : Time::Span
      delta = interval * @rand_factor
      min = interval - delta
      max = interval + delta
      randomized = random.rand(min.to_f..max.to_f)
      randomized.seconds
    end
  end
end
