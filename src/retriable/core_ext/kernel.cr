require "../../retriable"

module Retriable
  module KernelExtension
    delegate :retry, to: Retriable
  end
end

include Retriable::KernelExtension
