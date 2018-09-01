require "habitat"

module Retriable
  Habitat.create do
    setting max_attempts : UInt64?
    setting except : Exception.class | Array(Exception.class) | Nil
    setting on : Exception.class | Array(Exception.class) | Nil
    setting on_retry : Proc(Exception, UInt64, Time::Span, Time::Span, Nil)?
    setting base_interval : Time::Span = 0.5.seconds
    setting max_elapsed_time : Time::Span = 15.minutes
    setting max_interval : Time::Span = 1.minute
    setting multiplier : Float64 = 1.5
    setting sleep_disabled : Bool = false
    setting rand_factor : Float64 = 0.5
    setting random : Random = Random::DEFAULT
    setting intervals : Array(Time::Span)?
    setting backoff : Bool = true
  end

  class Settings
    def self.on_retry=(block : (Exception, UInt64, Time::Span, Time::Span) -> _)
      @@on_retry = ->(ex : Exception, attempt : UInt64, elapsed_time : Time::Span, interval : Time::Span) do
        block.call(ex, attempt, elapsed_time, interval)
        nil
      end
    end

    def self.on_retry(&block : (Exception, UInt64, Time::Span, Time::Span) -> _)
      self.on_retry = block
    end
  end
end
