module Retriable
  class Settings
    property max_attempts : Int32?
    property except : Exception.class | Array(Exception.class)?
    property on : Exception.class | Array(Exception.class)?
    property on_retry : Proc(Exception, Int32, Time::Span, Time::Span, Nil)?
    property base_interval : Time::Span = 0.5.seconds
    property max_elapsed_time : Time::Span = 15.minutes
    property max_interval : Time::Span = 1.minute
    property multiplier : Float64 = 1.5
    property? sleep_disabled : Bool = false
    property rand_factor : Float64 = 0.5
    property random : Random = Random::DEFAULT
    property intervals : Array(Time::Span)?
    property? backoff : Bool = true

    def on_retry(&block : (Exception, Int32, Time::Span, Time::Span) -> _)
      self.on_retry = block
    end
  end
end
