module Retriable
  struct ExponentialBackoff
    property base_interval : Time::Span
    property max_interval : Time::Span
    property rand_factor : Float64
    property multiplier : Float64
    property random : Random { Random::DEFAULT }

    def initialize(@base_interval, @max_interval, @rand_factor, @multiplier, @random = nil)
    end

    def randomize?
      !@rand_factor.zero?
    end

    def intervals : Iterator(Time::Span)
      should_randomize = randomize?
      (0..Int32::MAX).each.map do |iteration|
        interval = @multiplier**iteration
        interval = randomize(interval) if should_randomize
        {@base_interval * interval, @max_interval}.min
      rescue OverflowError
        @max_interval
      end
    end

    protected def randomize(interval) : Float64
      delta = interval * @rand_factor
      min = interval - delta
      max = interval + delta
      random.rand(min.to_f..max.to_f)
    end
  end
end
