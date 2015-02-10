require "rate/limiter/version"

module Rate
  module Limiter
    def call(env)
      [
        "200",
        {"Content-Type" => "text-html"},
        ["Test"]
      ]
    end
  end
end
