require "./lib/rate-limiter/store.rb"

class RateLimiter
  def initialize(app, options = {}, &block)
    @app         = app
    @limit       = options[:limit]    || 60
    @reset_in    = options[:reset_in] || 3600
    @block       = block
    @store       = options[:store]    || Store.new
    @remote_addr = nil
  end

  def call(env)
    @remote_addr = remote_addr(env)

    block_present_with_response?(env) ? @app.call(env) : call_with_additional_headers(env)
  end

  private

  def block_present_with_response?(env)
    !@block.nil? && @block.call(env).nil?
  end

  def remote_addr(env)
    @block.nil? ? env["REMOTE_ADDR"] : @block.call(env)
  end

  def call_with_additional_headers(env)
    create_hash_for_addr
    reset_time_and_limit

    @store.get(@remote_addr)[:remaining] > 0 ? update_remaining(env) : too_many_requests
  end

  def too_many_requests
    Rack::MockResponse.new(429, { "Content-Type" => "text-html" }, "Too Many Requests")
  end

  def create_hash_for_addr
    return if @store.get(@remote_addr)
    @store.set(@remote_addr, { remaining: @limit, reset_at: Time.now + @reset_in })
  end

  def reset_time_and_limit
    return unless @store.get(@remote_addr)[:reset_at] - Time.now < 0 
    client = @store.get(@remote_addr)
    client[:remaining] = @limit
    client[:reset_at] += @reset_in
    @store.set(@remote_addr, client)
  end

  def update_remaining(env)
    client = @store.get(@remote_addr)
    client[:remaining] = client[:remaining] - 1
    @store.set(@remote_addr, client)
    create_response(env, client[:remaining], client[:reset_at])
  end

  def create_response(env, remaining, reset_at)
    response = @app.call(env)
    response[1]["X-RateLimit-Limit"]     = @limit
    response[1]["X-RateLimit-Remaining"] = remaining
    response[1]["X-RateLimit-Reset"]     = reset_at
    response
  end
end
