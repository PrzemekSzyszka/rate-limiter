require "rubygems"
require "rack/test"
require "timecop"
require "memcached"
require 'dalli'
require 'minitest/autorun'
require './app.rb'
require './middleware.rb'


class MiddlewareTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @middleware = Middleware.new(App.new, { limit: 60, reset_in: 3600 })
  end

  def setup
    @middleware = Middleware.new(App.new, { limit: 60, reset_in: 3600 }) {  }
  end

  def test_app_returns_an_response
    get "/"
    assert_equal "Test", last_response.body
  end

  def test_header_has_x_retelimit_limit_in
    get "/"
    assert last_response.header.has_key?("X-RateLimit-Limit")
  end

  def test_x_retelimit_limit_header_has_value_specified
    get "/"
    assert_equal 60, last_response.header["X-RateLimit-Limit"]
  end

  def test_header_has_x_retelimit_remaining
    get "/"
    assert last_response.header.has_key?("X-RateLimit-Remaining")
  end

  def test_x_retelimit_remaining_value_decreses
    get "/"
    assert_equal 59, last_response.header["X-RateLimit-Remaining"]
    get "/"
    assert_equal 58, last_response.header["X-RateLimit-Remaining"]
  end

  def test_response_returns_too_many_requests_error
    get "/"
    60.times do
      get "/"
    end

    assert_equal 429, last_response.status
    assert_equal "Too Many Requests", last_response.body
  end

  def test_number_of_possible_requests_is_reseted
    current_time = Time.now

    2.times do
      get "/"
    end

    assert_equal 58, last_response.header["X-RateLimit-Remaining"]

    Timecop.travel(current_time + 3600)

    get "/"
    assert_equal 59, last_response.header["X-RateLimit-Remaining"]
  end

  def test_separated_limit_of_requests_for_each_ip
    get "/", {}, "REMOTE_ADDR" => "10.0.0.1"
    get "/", {}, "REMOTE_ADDR" => "10.0.0.1"

    assert_equal 58, last_response.header["X-RateLimit-Remaining"]

    get "/", {}, "REMOTE_ADDR" => "10.0.0.2"

    assert_equal 59, last_response.header["X-RateLimit-Remaining"]
  end

  def test_rate_limit_is_skipped
    get "/"

    assert_equal false, last_response.header.has_key?("X-RateLimit-Remaining")
  end

  def test_number_of_rate_limit_remaining_using_memcache_client
    options = { :namespace => "app_v1", :compress => true }
    dc = Dalli::Client.new('localhost:3000', options)
    dc.set('abc', 123)
    value = dc.get('abc')
  end
end
