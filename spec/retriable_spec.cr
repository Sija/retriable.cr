require "./spec_helper"

private class TestError < Exception
end

private class SecondTestError < TestError
end

private class DifferentTestError < Exception
end

describe Retriable do
  subject = Retriable

  opts = {
    random:       Random::PCG32.new(0_u64, 0_u64),
    max_attempts: 3,
  }

  context "with sleep disabled" do
    nosleep_opts = opts.merge(
      sleep_disabled: true,
    )

    it "applies a randomized exponential backoff to each try" do
      tries = 0
      time_table = [] of Time::Span

      handler = ->(_ex : Exception, _attempt : Int32, _elapsed_time : Time::Span, next_interval : Time::Span) do
        time_table << next_interval
      end

      expect_raises ArgumentError do
        subject.retry(**nosleep_opts.merge(
          on: {IO::EOFError, ArgumentError},
          on_retry: handler,
          times: 10,
        )) do
          tries += 1
          raise ArgumentError.new "ArgumentError occurred"
        end
      end

      time_table.should eq [
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

      tries.should eq(10)
    end

    context "#retry with no arguments" do
      it "retries given block" do
        tries = 0

        return_value = subject.retry(**nosleep_opts.merge(times: 10)) do
          tries += 1
          next subject.retry if tries < 5
          "fin"
        end
        return_value.should eq "fin"
        tries.should eq 5
      end
    end

    it "stops at first try if the block does not raise an exception" do
      tries = 0
      subject.retry(**nosleep_opts) do
        tries += 1
      end
      tries.should eq 1
    end

    it "returns inner value when given block doesn't raise" do
      inner_return = subject.retry(**nosleep_opts.merge(times: 10)) do |i|
        raise "foo #{i}!" if i < 3
        "bar #{i}!"
      end
      inner_return.should eq("bar 3!")
    end

    it "breaks the loop without given value" do
      inner_return = subject.retry(**nosleep_opts.merge(times: 10)) do |i|
        break if i == 3
        raise "foo!"
      end
      inner_return.should be_nil
    end

    it "returns value passed to break" do
      inner_return = subject.retry(**nosleep_opts) do
        break "bar!"
        "baz!"
      end
      inner_return.should eq("bar!")
    end

    it "returns value passed to next" do
      inner_return = subject.retry(**nosleep_opts) do
        next "bar!"
        "baz!"
      end
      inner_return.should eq("bar!")
    end

    it "makes 3 tries when retrying block of code raising Exception with no arguments" do
      tries = 0

      expect_raises Exception do
        subject.retry(**nosleep_opts) do
          tries += 1
          raise Exception.new "Exception occurred"
        end
      end
      tries.should eq 3
    end

    it "makes only 1 try when exception raised does not match given exception class" do
      tries = 0

      expect_raises TestError do
        subject.retry(ArgumentError, **nosleep_opts) do
          tries += 1
          raise TestError.new "TestError occurred"
        end
      end
      tries.should eq 1
    end

    it "tries 3 times and re-raises the custom exception" do
      tries = 0

      expect_raises TestError do
        subject.retry(**nosleep_opts.merge(on: TestError)) do
          tries += 1
          raise TestError.new "TestError occurred"
        end
      end
      tries.should eq 3
    end

    it "tries 10 times" do
      tries = 0

      expect_raises Exception, "Exception occurred: 10" do
        subject.retry(**nosleep_opts.merge(times: 10)) do |attempt|
          tries += 1
          tries.should eq(attempt)
          raise Exception.new "Exception occurred: #{attempt}"
        end
      end
      tries.should eq 10
    end

    it "makes only 1 try when exception raised matches given exception class" do
      tries = 0

      expect_raises SecondTestError, "Bad foo" do
        subject.retry(**nosleep_opts.merge(times: 10, except: SecondTestError)) do
          tries += 1
          case tries
          when .< 2
            raise ArgumentError.new "Just foo"
          when .< 3
            raise TestError.new "Another foo"
          else
            raise SecondTestError.new "Bad foo"
          end
        end
      end
      tries.should eq 3
    end

    it "makes only 1 try when exception raised matches given exception class" do
      tries = 0

      expect_raises SecondTestError, "Bad foo" do
        subject.retry(**nosleep_opts.merge(times: 10, on: TestError, except: SecondTestError)) do
          tries += 1
          case tries
          when .< 2
            raise SecondTestError.new "Bad foo"
          else
            raise TestError.new "Another foo"
          end
        end
      end
      tries.should eq 1
    end

    describe "retries with an on_retry handler, 6 max retries, and a 0.0 rand_factor" do
      total_tries = 6

      tries = 0
      time_table = {} of Int32 => Time::Span

      handler = ->(ex : Exception, attempt : Int32, _elapsed_time : Time::Span, next_interval : Time::Span) do
        ex.should be_a ArgumentError
        time_table[attempt] = next_interval
      end

      subject.retry(**opts.merge(
        on: [IO::EOFError, ArgumentError],
        on_retry: handler,
        rand_factor: 0.0,
        times: total_tries,
        sleep_disabled: true,
      )) do
        tries += 1
        raise ArgumentError.new "ArgumentError occurred" if tries < total_tries
      end

      it "makes 6 tries" do
        tries.should eq 6
      end

      it "applies a non-randomized exponential backoff to each try" do
        time_table.should eq({
          1 => 0.5.seconds,
          2 => 0.75.seconds,
          3 => 1.125.seconds,
          4 => 1.6875.seconds,
          5 => 2.53125.seconds,
        })
      end
    end

    it "has a max interval of 1.5 seconds" do
      tries = 0
      time_table = {} of Int32 => Time::Span

      handler = ->(_ex : Exception, attempt : Int32, _elapsed_time : Time::Span, next_interval : Time::Span) do
        time_table[attempt] = next_interval
      end

      expect_raises Exception do
        subject.retry(**nosleep_opts.merge(
          on: Exception,
          on_retry: handler,
          rand_factor: 0.0,
          times: 5,
          max_interval: 1.5.seconds,
        )) do
          tries += 1
          raise Exception.new "Exception occurred"
        end
      end

      time_table.should eq({
        1 => 0.5.seconds,
        2 => 0.75.seconds,
        3 => 1.125.seconds,
        4 => 1.5.seconds,
      })
      tries.should eq(5)
    end

    it "works with custom defined intervals" do
      intervals = {
        0.5,
        0.75,
        1.125,
        1.5,
        1.5,
      }

      tries = 0
      time_table = {} of Int32 => Time::Span

      handler = ->(_ex : Exception, attempt : Int32, _elapsed_time : Time::Span, next_interval : Time::Span) do
        time_table[attempt] = next_interval
      end

      expect_raises Exception do
        subject.retry(**nosleep_opts.merge(
          on_retry: handler,
          intervals: intervals,
        )) do
          tries += 1
          raise Exception.new "Exception occurred"
        end
      end

      time_table.should eq({
        1 => 0.5.seconds,
        2 => 0.75.seconds,
        3 => 1.125.seconds,
        4 => 1.5.seconds,
        5 => 1.5.seconds,
      })
      tries.should eq(6)
    end

    it "works with a hash exception where the value is an exception message pattern" do
      tries = 0
      ex = expect_raises TestError do
        subject.retry(**nosleep_opts.merge(on: {TestError => /something went wrong/})) do
          tries += 1
          raise TestError.new "something went wrong"
        end
      end
      ex.message.should eq "something went wrong"
      tries.should eq(3)
    end

    it "works with a hash exception list where the value is a Proc matcher" do
      ex_matches = ->(ex : Exception, attempt : Int32, _elapsed_time : Time::Span, _next_interval : Time::Span) do
        ex.should be_a TestError
        attempt.should be <= 3
        ex.message == "something went wrong"
      end
      tries = 0
      ex = expect_raises TestError do
        subject.retry(**nosleep_opts.merge(on: {TestError => ex_matches})) do
          tries += 1
          raise TestError.new "something went wrong"
        end
      end
      ex.message.should eq "something went wrong"
      tries.should eq(3)
    end

    it "works with a Proc matcher" do
      ex_matches = ->(ex : Exception, attempt : Int32, _elapsed_time : Time::Span, _next_interval : Time::Span) do
        ex.should be_a TestError
        attempt.should be <= 3
        ex.class <= TestError && ex.message == "something went wrong"
      end
      tries = 0
      ex = expect_raises TestError do
        subject.retry(**nosleep_opts.merge(on: ex_matches)) do
          tries += 1
          raise TestError.new "something went wrong"
        end
      end
      ex.message.should eq "something went wrong"
      tries.should eq(3)
    end

    it "works with a hash exception list matches exception subclasses" do
      tries = 0
      ex = expect_raises SecondTestError do
        subject.retry(**nosleep_opts.merge(
          on: {
            TestError          => /something went wrong/,
            DifferentTestError => /should never happen/,
          },
          times: 4
        )) do
          tries += 1
          raise SecondTestError.new "something went wrong"
        end
      end
      ex.message.should eq "something went wrong"
      tries.should eq 4
    end

    it "works with a hash exception list does not retry matching exception subclass but not message" do
      tries = 0
      expect_raises SecondTestError do
        subject.retry(**nosleep_opts.merge(
          on: {TestError => /something went wrong/},
          times: 4
        )) do
          tries += 1
          raise SecondTestError.new "not a match"
        end
      end
      tries.should eq 1
    end

    it "works with a hash exception list where the values are exception message patterns" do
      tries = 0
      exceptions = {} of Int32 => Exception

      handler = ->(ex : Exception, attempt : Int32, _elapsed_time : Time::Span, _next_interval : Time::Span) do
        exceptions[attempt] = ex
      end

      ex = expect_raises(TestError) do
        subject.retry(**nosleep_opts.merge(
          on: {ArgumentError => nil, TestError => {/foo/, /bar/}},
          on_retry: handler,
          times: 5,
        )) do
          tries += 1
          case tries
          when 1
            raise TestError.new("foo")
          when 2
            raise TestError.new("bar")
          when 3
            raise ArgumentError.new("baz")
          when 4
            raise ArgumentError.new(nil)
          else
            raise TestError.new("crash")
          end
        end
      end

      ex.message.should eq "crash"
      exceptions[1].class.should eq TestError
      exceptions[1].message.should eq "foo"
      exceptions[2].class.should eq TestError
      exceptions[2].message.should eq "bar"
      exceptions[3].class.should eq ArgumentError
      exceptions[3].message.should eq "baz"
      exceptions[4].class.should eq ArgumentError
      exceptions[4].message.should be_nil
    end
  end

  it "runs for a max elapsed time of 2 seconds" do
    sleep_opts = opts.merge(
      sleep_disabled: false,
    )

    tries = 0
    time_table = {} of Int32 => Time::Span

    handler = ->(_ex : Exception, attempt : Int32, _elapsed_time : Time::Span, next_interval : Time::Span) do
      time_table[attempt] = next_interval
    end

    expect_raises(Exception) do
      subject.retry(**sleep_opts.merge(
        base_interval: 1.second,
        multiplier: 1.0,
        rand_factor: 0.0,
        max_elapsed_time: 2.seconds,
        on_retry: handler,
      )) do
        tries += 1
        raise Exception.new
      end
    end

    time_table.should eq({
      1 => 1.second,
    })
    tries.should eq 2
  end
end
