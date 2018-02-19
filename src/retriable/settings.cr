require "habitat"

module Retriable
  Habitat.create do
    setting max_attempts : Int32?
    setting on : Exception.class | Array(Exception.class) = Exception
    setting on_retry : Proc(Exception, Int32, Time::Span, Time::Span, Nil)?
    setting base_interval : Time::Span = 0.5.seconds
    setting max_elapsed_time : Time::Span = 15.minutes
    setting max_interval : Time::Span = 1.minute
    setting multiplier : Float64 = 1.5
    setting sleep_disabled : Bool = false
    setting timeout : Time::Span?
    setting rand_factor : Float64 = 0.5
    setting random : Random = Random::DEFAULT
    setting intervals : Array(Time::Span)?
    setting backoff : Bool = true
  end

  class Settings
    def self.on_retry=(block : (Exception, Int32, Time::Span, Time::Span) -> _)
      @@on_retry = ->(ex : Exception, attempt : Int32, elapsed_time : Time::Span, interval : Time::Span) do
        block.call(ex, attempt, elapsed_time, interval)
        nil
      end
    end

    def self.on_retry(&block : (Exception, Int32, Time::Span, Time::Span) -> _)
      self.on_retry = block
    end
  end
end
