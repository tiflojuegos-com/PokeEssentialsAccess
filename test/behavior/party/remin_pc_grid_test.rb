# Reminiscencia's PC box is eight slots wide: the profile's column count is the game's NUMROWS, the horizontal stride
# its cursor moves by (the game's names are swapped), and the shared width stands without a usable one.
remin_pc_grid_path = File.join(Harness::ROOT, "games", "reminiscencia", "pc_grid.rb")
eval(Harness.source(remin_pc_grid_path), TOPLEVEL_BINDING, remin_pc_grid_path)

class ReminPcGridTest < PokeAccessTest
  test "a row holds what the game's cursor stride says, and the shared six where it says nothing usable" do
    { 8 => 8, 1 => 1, 0 => 6, -3 => 6, "8" => 6 }.each do |numrows, columns|
      with_numrows(numrows) do
        assert_equal columns, PokeAccess::Party.box_columns, "NUMROWS #{numrows.inspect}"
      end
    end
  end

  test "without the game's constant the shared width stands" do
    assert_equal 6, PokeAccess::Party.box_columns
  end

  private

  # Runs the block with the game's NUMROWS set to value, then takes it away.
  def with_numrows(value)
    Object.const_set(:NUMROWS, value)
    yield
  ensure
    Object.send(:remove_const, :NUMROWS) if Object.const_defined?(:NUMROWS)
  end
end
