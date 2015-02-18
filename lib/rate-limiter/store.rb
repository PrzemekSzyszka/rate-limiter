class Store
  def initialize
    @products = {}
  end

  def get(name)
    return unless @products.has_key?(name)
    @products[name]
  end

  def set(name, value)
    @products[name] = value
  end
end
