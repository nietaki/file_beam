defmodule FileBeam.UtilsTest do
  use ExUnit.Case
  import FileBeam.Utils

  describe "get_random_id/0" do
    test "consists of the right characters" do
      id = get_random_id()
      assert Regex.match?(~r/^[a-zA-Z0-9]+$/, id)
    end

    test "is of the right length" do
      id = get_random_id()
      assert String.length(id) == 10
    end

    test "isn't always the same" do
      assert get_random_id() != get_random_id()
    end
  end
end
