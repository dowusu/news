defmodule NewsTest do
  use ExUnit.Case
  doctest News

  test "greets the world" do
    assert News.hello() == :world
  end
end
