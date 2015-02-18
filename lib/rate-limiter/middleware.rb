class Middleware
  def initialize(app, options, &block)
    @app = app
    @options = options
    @left_requests = {}
    @block = block
  end

  def call(env)
    if @options[:store].nil?
      if @block.nil?
        prepare_headers(env, env["REMOTE_ADDR"])
      else
        response = @block.call(env)

        if response.nil?
          @app.call(env)
        else
          prepare_headers(env, response)
        end
      end
    else
      create_dalli_hash_for_addr(env["REMOTE_ADDR"], @options[:store])
      reset_dalli_time_and_remaining(env["REMOTE_ADDR"], @options[:store])
      add_dalli_headers(env, env["REMOTE_ADDR"], @options[:store])
    end
  end

  private

  def prepare_headers(env, host_addres)
    create_hash_for_addr(host_addres)

    reset_time_and_remaining(host_addres)

    if @left_requests[host_addres][:remaining] > 0
      add_headers(env, host_addres)
    else
      Rack::MockResponse.new(429, { "Content-Type" => "text-html" }, "Too Many Requests")
    end
  end

  def create_hash_for_addr(remote_addr)
    unless @left_requests.has_key?(remote_addr)
      @left_requests[remote_addr] = {}
      @left_requests[remote_addr][:remaining] = @options[:limit]
      @left_requests[remote_addr][:reset_at]  = Time.now + @options[:reset_in]
    end
  end

  def create_dalli_hash_for_addr(remote_addr, store)
    if store.get(remote_addr).nil?
      store.set(remote_addr, { remaining: @options[:limit], reset_at: Time.now + @options[:reset_in] })
    end
  end

  def reset_time_and_remaining(remote_addr)
    if @left_requests[remote_addr][:reset_at] - Time.now < 0
      @left_requests[remote_addr][:remaining] = @options[:limit]
      @left_requests[remote_addr][:reset_at] += @options[:reset_in]
    end
  end

  def reset_dalli_time_and_remaining(remote_addr, store)
    client = store.get(remote_addr)
    if client[:reset_at] - Time.now < 0
      client[:remaining] = @options[:limit]
      client[:reset_at] += @options[:reset_in]
      store.set(remote_addr, store)
    end
  end

  def add_headers(env, remote_addr)
    @left_requests[remote_addr][:remaining] -= 1
    create_response(env, @options[:limit], @left_requests[remote_addr][:remaining], @left_requests[remote_addr][:reset_at])
  end

  def add_dalli_headers(env, remote_addr, store)
    client = store.get(remote_addr)
    client[:remaining] = client[:remaining] - 1
    store.set(remote_addr, client)
    create_response(env, @options[:limit], client[:remaining], client[:reset_at])
  end

  def create_response(env, limit, remaining, reset_at)
    response = @app.call(env)
    response[1]["X-RateLimit-Limit"]     = limit
    response[1]["X-RateLimit-Remaining"] = remaining
    response[1]["X-RateLimit-Reset"]     = reset_at
    response
  end
end
