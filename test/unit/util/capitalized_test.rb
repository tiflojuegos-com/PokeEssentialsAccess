# Util.capitalized, Ruby's own capitalize whatever the game did to String#capitalize: the first letter up, the rest
# down, an empty or nil text as an empty string.

class CapitalizedTest < PokeAccessTest
  test "raises the first letter and lowers the rest" do
    { "VIAL" => "Vial", "pikachu" => "Pikachu", "pOKé ball" => "Poké ball", "x" => "X", "" => "", nil => "",
      :CUT => "Cut" }.each do |text, expected|
      assert_equal expected, PokeAccess::Util.capitalized(text), "for #{text.inspect}"
    end
  end

  test "keeps to Ruby's own behavior under a game's String#capitalize" do
    String.class_eval do
      alias_method :capitalize__spec, :capitalize
      define_method(:capitalize) { self[0, 1].upcase + self[1..-1] }
    end
    assert_equal "Vial", PokeAccess::Util.capitalized("VIAL")
  ensure
    String.class_eval do
      alias_method :capitalize, :capitalize__spec
      remove_method :capitalize__spec
    end
  end
end
