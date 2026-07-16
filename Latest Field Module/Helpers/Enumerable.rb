module Enumerable
  alias has? include?
  alias contain? include?
  alias includes? include?
  alias contains? include?

  def remove(*items)
    items.flatten.each { |item| delete(item) }
  end
end