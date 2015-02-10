class RateLimiter
  def call(env)
    [
      "200",
      {"Content-Type" => "text-html"},
      ["Test"]
    ]
  end
end
