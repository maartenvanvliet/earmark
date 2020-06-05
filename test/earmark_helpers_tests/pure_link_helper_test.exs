defmodule Earmark.Helpers.TestPureLinkHelpers do

  use ExUnit.Case, async: true
  import Earmark.Helpers.PureLinkHelpers, only: [convert_pure_link: 1]

  describe "Pure Links" do
    test "nothing fancy just a plain link" do
      #                           0....+....1....+...
      result = convert_pure_link("https://a.link.com")
      expected = {{"a", [{"href", "https://a.link.com"}], ["https://a.link.com"]}, 18}
      assert result == expected
    end

    test "trailing parens are not part of it" do
      #                           0....+....1....+...
      result = convert_pure_link("https://a.link.com)")
      expected = {{"a", [{"href", "https://a.link.com"}], ["https://a.link.com"]}, 18}
      assert result == expected
    end

    test "however opening parens are" do
      #                           0....+....1....+...
      result = convert_pure_link("https://a.link.com(")
      expected = {{"a", [{"href", "https://a.link.com("}], ["https://a.link.com("]}, 19}
      assert result == expected
    end

    test "closing parens inside are ok" do
      #                0....+....0 ....+....1 ....+....2 ....+..
      result = convert_pure_link("www.google.com/search?q=(business))+ok")
      expected = {{"a", [{"href", "www.google.com/search?q=(business))+ok"}], ["www.google.com/search?q=(business))+ok"]}, 25}
      assert result == expected
    end
  end

end
