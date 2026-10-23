# A move's power off its GameData under each era's name: display_power (v20+) and display_damage (Soulstones 2, the
# figure its page paints) before the plain figure, power (v20+) or base_damage (v19).
class MovePowerGdTest < PokeAccessTest
  test "finds a move's power under each era's name for it" do
    { "v19's base_damage" => [{ :base_damage => 90 }, 90],
      "Soulstones 2's display_damage, the figure its page paints" => [{ :display_damage => 120, :base_damage => 90 }, 120],
      "v20's display_power before its power" => [{ :display_power => 70, :power => 60 }, 70],
      "display_power before display_damage" => [{ :display_power => 70, :display_damage => 120 }, 70],
      "plain power where nothing else answers" => [{ :power => 40 }, 40],
      "power before base_damage" => [{ :power => 40, :base_damage => 90 }, 40] }.each do |what, (answers, want)|
      assert_equal want, PokeAccess::SummaryGameData.move_power(move_data(answers), :pk, :mv), what
    end
  end

  test "asks display_power with the Pokemon and the move the page shows" do
    data = Object.new
    data.define_singleton_method(:display_power) { |pk, mv| pk == :pk && mv == :mv ? 75 : 0 }
    assert_equal 75, PokeAccess::SummaryGameData.move_power(data, :pk, :mv)
  end

  test "goes on to the next name when a display figure is nil or raises" do
    raises = lambda { raise "no Pokemon" }
    cases = { "a nil display_power" => [{ :display_power => nil, :display_damage => 55, :power => 60 }, 55],
              "a display_power that raises" => [{ :display_power => raises, :power => 60 }, 60],
              "a display_damage that raises" => [{ :display_damage => raises, :base_damage => 85 }, 85] }
    cases.each do |what, (answers, want)|
      assert_equal want, PokeAccess::SummaryGameData.move_power(move_data(answers), :pk, :mv), what
    end
  end

  test "gives 0 for a move whose data names no power" do
    assert_equal 0, PokeAccess::SummaryGameData.move_power(Object.new, :pk, :mv)
  end

  private

  # A move's data answering each name with its figure; a display_* name takes the Pokemon and the move, and a lambda
  # figure is called (to raise).
  def move_data(answers)
    data = Object.new
    answers.each do |name, v|
      figure = lambda { v.is_a?(Proc) ? v.call : v }
      if name.to_s.start_with?("display_")
        data.define_singleton_method(name) { |_pk, _mv| figure.call }
      else
        data.define_singleton_method(name) { figure.call }
      end
    end
    data
  end
end
