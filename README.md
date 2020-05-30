# retriable.cr [![Build Status](https://travis-ci.com/Sija/retriable.cr.svg?branch=master)](https://travis-ci.com/Sija/retriable.cr) [![Releases](https://img.shields.io/github/release/Sija/retriable.cr.svg)](https://github.com/Sija/retriable.cr/releases) [![License](https://img.shields.io/github/license/Sija/retriable.cr.svg)](https://github.com/Sija/retriable.cr/blob/master/LICENSE)

Retriable is a simple DSL to retry failed code blocks with randomized [exponential backoff](https://en.wikipedia.org/wiki/Exponential_backoff) time intervals. This is especially useful when interacting external APIs, remote services, or file system calls.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  retriable:
    github: Sija/retriable.cr
```

## Usage

Code in a `Retriable.retry` block will be retried if either an exception is
raised or `next retry` is called.

```crystal
require "retriable"

class Api
  # Use it in methods that interact with unreliable services
  def get
    Retriable.retry do
      # code here...
    end
  end
end
```

### Defaults

By default, `Retriable` will:

* rescue any exception inherited from `Exception`
* use randomized exponential backoff to calculate each succeeding try interval.

The default interval table with 10 tries looks like this (in seconds, rounded to the nearest millisecond):

| Retry #  | Min      | Average  | Max      |
| -------- | -------- | -------- | -------- |
| 1        | `0.25`   | `0.5`    | `0.75`   |
| 2        | `0.375`  | `0.75`   | `1.125`  |
| 3        | `0.563`  | `1.125`  | `1.688`  |
| 4        | `0.844`  | `1.688`  | `2.531`  |
| 5        | `1.266`  | `2.531`  | `3.797`  |
| 6        | `1.898`  | `3.797`  | `5.695`  |
| 7        | `2.848`  | `5.695`  | `8.543`  |
| 8        | `4.271`  | `8.543`  | `12.814` |
| 9        | `6.407`  | `12.814` | `19.222` |
| 10       | **stop** | **stop** | **stop** |

### Options

Here are the available options, in some vague order of relevance to most common use patterns:

| Option                  | Default           | Definition                    |
| ----------------------- | ----------------- | ----------------------------- |
| **`max_attempts`**      | `nil`             | Number of attempts to make at running your code block (includes initial attempt). |
| **`except`**            | `nil`             | Type of exceptions to NOT retry. [Read more](#configuring-which-options-to-retry-with-onexcept). |
| **`on`**                | `nil`             | Type of exceptions to retry. [Read more](#configuring-which-options-to-retry-with-onexcept). |
| **`on_retry`**          | `nil`             | `Proc` to call after each try is rescued. [Read more](#callbacks). |
| **`base_interval`**     | `0.5.seconds`     | The initial interval between tries. |
| **`max_elapsed_time`**  | `15.minutes`      | The maximum amount of total time that code is allowed to keep being retried. |
| **`max_interval`**      | `1.minute`        | The maximum interval that any individual retry can reach. |
| **`multiplier`**        | `1.5`             | Each successive interval grows by this factor. A multiplier of 1.5 means the next interval will be 1.5x the current interval. |
| **`rand_factor`**       | `0.5`             | The percentage to randomize the next retry interval time. The next interval calculation is `randomized_interval = retry_interval * (random value in range [1 - randomization_factor, 1 + randomization_factor])` |
| **`intervals`**         | `nil`             | Skip generated intervals and provide your own `Enumerable` of intervals in seconds. [Read more](#customizing-intervals). |
| **`backoff`**           | `true`            | Whether backoff strategy should be used. |
| **`random`**            | `Random::DEFAULT` | Object inheriting from `Random`, which provides an interface for random values generation, using a pseudo random number generator (PRNG). |

#### Configuring which options to retry with :on/:except

**`:on`** / **`:except`** Can take the form:

- An `Exception` class (retry every exception of this type, including subclasses)
- An `Enumerable` of `Exception` classes (retry any exception of one of these types, including subclasses)
- A single `Proc` (retries exceptions ONLY if return is _truthy_)
- A `Hash` where the keys are `Exception` classes and the values are one of:
  - `nil` (retry every exception of the key's type, including subclasses)
  - A single `Proc` (retries exceptions ONLY for non `nil` returns)
  - A single `Regex` pattern (retries exceptions ONLY if their `message` matches the pattern)
  - An `Enumerable` of patterns (retries exceptions ONLY if their `message` matches at least one of the patterns)

### Configuration

You can change the global defaults with a `#configure` block:

```crystal
Retriable.configure do |settings|
  settings.max_attempts = 5
  settings.max_elapsed_time = 1.hour
end
```

### Example usage

This example will only retry on a `IO::Timeout`, retry 3 times and sleep for a full second before each try.

```crystal
Retriable.retry(on: IO::Timeout, times: 3, base_interval: 1.second) do
  # code here...
end
```

You can also specify multiple errors to retry on by passing an `Enumerable` of exceptions.

```crystal
Retriable.retry(on: {IO::Timeout, Errno::ECONNRESET}) do
  # code here...
end
```

You can also use a `Hash` to specify that you only want to retry exceptions with certain messages (see [the documentation above](#configuring-which-options-to-retry-with-on)). This example will retry all `ActiveRecord::RecordNotUnique` exceptions, `ActiveRecord::RecordInvalid` exceptions where the message matches either `/Parent must exist/` or `/Username has already been taken/`, or `Mysql2::Error` exceptions where the message matches `/Duplicate entry/`.

```crystal
Retriable.retry(on: {
  ActiveRecord::RecordNotUnique => nil,
  ActiveRecord::RecordInvalid => [/Parent must exist/, /Username has already been taken/],
  ActiveRecord::RecordNotFound => ->(ex : Exception, attempt : Int32, elapsed : Time::Span, interval : Time::Span) {
    {User, Post}.includes?(ex.model.class)
  },
  Mysql2::Error => /Duplicate entry/,
}) do
  # code here...
end
```

### Customizing intervals

You can also bypass the built-in interval generation and provide your own `Enumerable` of intervals. Supplying your own intervals overrides the `max_attempts`, `base_interval`, `max_interval`, `rand_factor`, and `multiplier` parameters.

```crystal
Retriable.retry(intervals: {0.5, 1.0, 2.0, 2.5}) do
  # code here...
end
```

This example makes 5 total attempts. If the first attempt fails, the 2nd attempt occurs 0.5 seconds later.

### Turning off exponential backoff

Exponential backoff is enabled by default. If you want to simply retry code every second, 5 times maximum, you can do this:

```crystal
Retriable.retry(times: 5, base_interval: 1.second, multiplier: 1.0, rand_factor: 0.0) do
  # code here...
end
```

This works by starting at a 1 second `base_interval`. Setting the `multiplier` to 1.0 means each subsequent try will increase 1x, which is still `1.0` seconds, and then a `rand_factor` of 0.0 means that there's no randomization of that interval. (By default, it would randomize 0.5 seconds, which would mean normally the intervals would randomize between 0.75 and 1.25 seconds, but in this case `rand_factor` is basically being disabled.)

Same thing can be done by passing `backoff: false` option.

```crystal
Retriable.retry(times: 5, backoff: false) do
  # code here...
end
```

Another way to accomplish this would be to create an array with a fixed interval. In this example, `Array.new(5, 1.second)` creates an array with 5 elements, all with the value of 1 second as `Time::Span` instances. The code block will retry up to 5 times, and wait 1 second between each attempt.

```crystal
# Array.new(5, 1.second) # => [00:00:01, 00:00:01, 00:00:01, 00:00:01, 00:00:01]

Retriable.retry(intervals: Array.new(5, 1.second)) do
  # code here...
end
```

If you don't want exponential backoff but you still want some randomization between intervals, this code will run every 1 seconds with a randomization factor of 0.2, which means each interval will be a random value between 0.8 and 1.2 (1 second +/- 0.2):

```crystal
Retriable.retry(base_interval: 1.second, multiplier: 1.0, rand_factor: 0.2) do
  # code here...
end
```

### Callbacks

`#retry` also provides a callback called `:on_retry` that will run after an exception is rescued. This callback provides the `exception` that was raised in the current try, the `try_number`, the `elapsed_time` for all tries so far, and the time (as a `Time::Span`) of the `next_interval`.

```crystal
do_this_on_each_retry = ->(ex : Exception, attempt : Int32, elapsed_time : Time::Span, next_interval : Time::Span) do
  log "#{ex.class}: '#{ex.message}' - #{attempt} attempt in #{elapsed_time} seconds and #{next_interval} seconds until the next try."
end

Retriable.retry(on_retry: do_this_on_each_retry) do
  # code here...
end
```

### Ensure/Else

What if I want to execute a code block at the end, whether or not an exception was rescued ([ensure](https://crystal-lang.org/docs/syntax_and_semantics/exception_handling.html#ensure))? Or what if I want to execute a code block if no exception is raised ([else](https://crystal-lang.org/docs/syntax_and_semantics/exception_handling.html#else))? Instead of providing more callbacks, I recommend you just wrap retriable in a begin/retry/else/ensure block:

```crystal
begin
  Retriable.retry do
    # some code
  end
rescue ex
  # run this if retriable ends up re-rasing the exception
else
  # run this if retriable doesn't raise any exceptions
ensure
  # run this no matter what, exception or no exception
end
```

## Kernel extension

If you want to call `Retriable.retry` without the `Retriable` module prefix and you don't mind extending `Kernel`,
there is a kernel extension available for this.

In your crystal program:

```crystal
require "retriable/core_ext/kernel"
```

and then you can call `#retry` in any context like this:

```crystal
retry do
  # code here...
end
```

## Contributors

- [@Sija](https://github.com/Sija) Sijawusz Pur Rahnama - creator, maintainer

## Thanks

Thanks to all of the contributors for their awesome work on [Retriable](https://github.com/kamui/retriable) gem, from which this shard was ported.
