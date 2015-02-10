module Rate
  module Limiter
    class Middleware
      def initialize(app, options, &block)
        @app = app
        @options = options
        @left_requests = {}
        @block_return = block_given? ? block.call : "Some default value"
        if block_given?
          p block.call
        end
      end

      def call(env)
        if @options[:store].nil?
          unless @block_return.nil?
            create_hash_for_addr(env["REMOTE_ADDR"])

            reset_time_and_remaining(env["REMOTE_ADDR"])

            if @left_requests[env["REMOTE_ADDR"]][:remaining] > 0
              add_headers(env, env["REMOTE_ADDR"])
            else
              Rack::MockResponse.new(429, { "Content-Type" => "text-html" }, "Too Many Requests")
            end
          else
            @app.call(env)
          end
        else
          create_dalli_hash_for_addr(env["REMOTE_ADDR"], @options[:store])
          reset_dalli_time_and_remaining(env["REMOTE_ADDR"], @options[:store])
          reset_dalli_time_and_remaining
        end
      end

      private

      def create_hash_for_addr(remote_addr)
        unless @left_requests.has_key?(remote_addr)
          @left_requests[remote_addr] = {}
          @left_requests[remote_addr][:remaining] = @options[:limit]
          @left_requests[remote_addr][:reset_at]  = Time.now + @options[:reset_in]
        end
      end

      def create_dalli_hash_for_addr(remote_addr, client)
        unless client.get(remote_addr).nil?
          client.set(remote_addr, {})
          client.set(remote_addr[:remaining], @options[:limit])
          client.set(remote_addr[:reset_at], Time.now + @options[:reset_in])
        end
      end

      def reset_time_and_remaining(remote_addr)
        if @left_requests[remote_addr][:reset_at] - Time.now < 0
          @left_requests[remote_addr][:remaining] = @options[:limit]
          @left_requests[remote_addr][:reset_at] += @options[:reset_in]
        end
      end

      def reset_dalli_time_and_remaining(remote_addr, client)
        if client.get(remote_addr)[:reset_at] - Time.now < 0
          client.get(remote_addr)[:remaining] = @options[:limit]
          client.get(remote_addr)[:reset_at] += @options[:reset_in]
        end
      end

      def add_headers(env, remote_addr)
        @left_requests[remote_addr][:remaining] -= 1
        response = @app.call(env)
        response[1]["X-RateLimit-Limit"]     = @options[:limit]
        response[1]["X-RateLimit-Remaining"] = @left_requests[remote_addr][:remaining]
        response[1]["X-RateLimit-Reset"]     = @left_requests[remote_addr][:reset_at]
        response
      end

      def add_dalli_headers(env, remote_addr, client)
        client.set(remote_addr[:remaining], client.get(remote_addr[:remaining]) - 1)
        response = @app.call(env)
        response[1]["X-RateLimit-Limit"]     = @options[:limit]
        response[1]["X-RateLimit-Remaining"] = client.get(remote_addr[:remaining])
        response[1]["X-RateLimit-Reset"]     = client.get(remote_addr[:reset_at])
        response
      end
    end
  end
end
