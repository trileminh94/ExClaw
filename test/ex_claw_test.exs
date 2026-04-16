defmodule ExClawTest do
  use ExUnit.Case
  doctest ExClaw

  test "greets the world" do
    assert ExClaw.hello() == :world
  end
end
