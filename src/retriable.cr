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

  class_getter settings : Settings { Settings.new }

  def configure : Nil
    yield settings
  end

  def retry
    Retry
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def retry(on = nil, **opts)
    base_interval = opts[:base_interval]? || settings.base_interval
    max_interval = opts[:max_interval]? || settings.max_interval
    rand_factor = opts[:rand_factor]? || settings.rand_factor
    random = opts[:random]? || settings.random
    multiplier = opts[:multiplier]? || settings.multiplier
    max_elapsed_time = opts[:max_elapsed_time]? || settings.max_elapsed_time
    intervals = opts[:intervals]? || settings.intervals
    max_attempts = opts[:times]? || opts[:max_attempts]? || settings.max_attempts
    sleep_disabled = opts[:sleep_disabled]? || settings.sleep_disabled?
    except = opts[:except]? || settings.except
    on = on || opts[:only]? || settings.on
    on_retry = opts[:on_retry]? || settings.on_retry
    backoff = opts[:backoff]? || settings.backoff?

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
      intervals = intervals.each
      if max_attempts && !settings.max_attempts
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

    initial_intervals = intervals.dup

    start_time = Time.monotonic
    attempt = 0
    loop do
      attempt += 1
      begin
        return_value = yield attempt
        return return_value unless return_value == Retry
      rescue ex
        elapsed_time = Time.monotonic - start_time

        case interval = intervals.next
        when Iterator::Stop
          intervals = initial_intervals.dup
          interval = intervals.first
        end

        raise ex if on && should_raise?(on, ex, attempt, elapsed_time, interval)
        raise ex if except && !should_raise?(except, ex, attempt, elapsed_time, interval)

        raise ex if max_attempts && (attempt >= max_attempts)
        raise ex if (elapsed_time + interval) > max_elapsed_time

        on_retry.try &.call(ex, attempt, elapsed_time, interval)

        sleep interval unless sleep_disabled || interval.zero?
      end
    end
  end

  protected def should_raise?(on : Exception.class | Proc | Enumerable, ex, *proc_args)
    !matches_exception?(on, ex, *proc_args)
  end

  # ameba:disable Metrics/CyclomaticComplexity
  protected def matches_exception?(on : Nil | Exception.class | Regex | Proc | Enumerable, ex, *proc_args)
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
    end
  end
end
