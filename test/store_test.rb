require "minitest/autorun"
require "./lib/rate-limiter/store.rb"

class StoreTest < Minitest::Test

  def setup
    @store = Store.new
  end

  def test_set_and_get
    @store.set("name", "Stefan")

    assert_equal "Stefan", @store.get("name")
  end
end
