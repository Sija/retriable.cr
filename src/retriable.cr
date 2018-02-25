require "./retriable/*"

# ```
# # include it scoped to the Retriable module
# require "retriable"
#
# Retriable.retry do
#   # ...
# end
#
# # or include it into top level namespace
# require "retriable/core_ext/kernel"
#
# retry do
#   # ...
# end
# ```
module Retriable
  extend self

  private abstract class Retry
  end

  def retry
    Retry
  end

  def retry(on = nil, **opts)
    base_interval = opts[:base_interval]? || settings.base_interval
    max_interval = opts[:max_interval]? || settings.max_interval
    rand_factor = opts[:rand_factor]? || settings.rand_factor
    random = opts[:random]? || settings.random
    multiplier = opts[:multiplier]? || settings.multiplier
    max_elapsed_time = opts[:max_elapsed_time]? || settings.max_elapsed_time
    intervals = opts[:intervals]? || settings.intervals?
    max_attempts = opts[:times]? || opts[:max_attempts]? || settings.max_attempts?
    timeout = opts[:timeout]? || settings.timeout?
    sleep_disabled = opts[:sleep_disabled]? || settings.sleep_disabled
    on = on || opts[:only]? || settings.on
    on_retry = opts[:on_retry]? || settings.on_retry?
    backoff = opts[:backoff]? || settings.backoff

    if backoff == false
      base_interval = 0.seconds
      multiplier = 1.0
      rand_factor = 0.0
    end

    backoff = ExponentialBackoff.new(
      base_interval: base_interval,
      multiplier: multiplier,
      max_interval: max_interval,
      rand_factor: rand_factor,
      random: random
    )

    case intervals
    when Enumerable(Int::Primitive | Float64)
      intervals = intervals.map(&.seconds)
    end

    case intervals
    when Enumerable(Time::Span)
      intervals_size = intervals.size + 1
      intervals = intervals.each.rewind
      if max_attempts && !settings.max_attempts?
        if max_attempts > intervals_size
          intervals = intervals.chain(backoff.intervals.skip(intervals_size))
        else
          max_attempts = intervals_size
        end
      else
        max_attempts = intervals_size
      end
    when Nil
      intervals = backoff.intervals
    end

    start_time = Time.monotonic
    loop do |index|
      attempt = index + 1
      begin
        return_value = yield attempt
        unless return_value == Retry
          return return_value
        end
      rescue ex
        elapsed_time = Time.monotonic - start_time

        case interval = intervals.next
        when Iterator::Stop
          intervals.rewind
          interval = intervals.first
        end

        raise ex if !matches_exception?(on, ex, attempt, elapsed_time, interval)
        raise ex if max_attempts && (attempt >= max_attempts)
        raise ex if (elapsed_time + interval) > max_elapsed_time

        on_retry.try &.call(ex, attempt, elapsed_time, interval)

        sleep interval unless sleep_disabled || interval.zero?
      end
    end
  end

  protected def matches_exception?(on, ex, *proc_args)
    case on
    when Nil
      true
    when Exception.class
      on >= ex.class
    when Regex
      on =~ ex.message
    when Proc
      on.call(ex, *proc_args)
    when Hash
      on.any? do |klass, value|
        next unless klass >= ex.class
        case value
        when Nil, Regex, Proc
          matches_exception?(value, ex, *proc_args)
        when Enumerable
          value.any? do |matcher|
            case matcher
            when Regex, Proc
              matches_exception?(matcher, ex, *proc_args)
            end
          end
        end
      end
    when Enumerable
      on.any? do |matcher|
        case matcher
        when Exception.class, Proc
          matches_exception?(matcher, ex, *proc_args)
        end
      end
    else
      false
    end
  end
end
