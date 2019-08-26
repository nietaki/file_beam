defmodule FileBeam.Middleware.ResponseCompressionTest do
  use ExUnit.Case

  import FileBeam.Middleware.ResponseCompression

  describe "parse_encoding_preferences" do
    test "missing" do
      assert [] = parse_encoding_preferences("")
      assert [] = parse_encoding_preferences(nil)
    end

    test "one" do
      assert ["foo"] = parse_encoding_preferences("foo")
      assert [] = parse_encoding_preferences(nil)
    end

    test "multiple" do
      assert ["foo", "bar"] = parse_encoding_preferences("foo, bar")
      assert ["bar", "foo"] = parse_encoding_preferences("foo;q=0.8, bar")
    end
  end

  describe "parse_encoding_qvalue" do
    test "on a simple value" do
      assert {"foo", 1.0} == parse_encoding_qvalue("foo")
    end

    test "with a qvalue" do
      assert {"foo", 0.8} == parse_encoding_qvalue("foo;q=0.8")
    end

    test "broken" do
      assert {"foo", 1.0} == parse_encoding_qvalue("foo;q=dlfks=jlf")
      assert {"foo", 1.0} == parse_encoding_qvalue("foo;q=dlf;q=ksjlf")
    end
  end
end
