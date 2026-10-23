# Summary.eviv_rows, the EV and IV rows of the five-page summaries (Insurgence, Soulstones 1, the Reborn engine): one
# per stat, in the stock gen-6 order with speed last, or in the order an engine numbers its stats.
class SummaryEvivRowsTest < PokeAccessTest
  EVS = [10, 20, 30, 40, 50, 60].freeze
  IVS = [1, 2, 3, 4, 5, 6].freeze

  test "lists each stat's EV and IV in the stock gen-6 order, speed last though it is stat 3" do
    pk = Poke.build(:ev => EVS, :iv => IVS)
    assert_equal [row(:st_hp, 10, 1), row(:st_atk, 20, 2), row(:st_def, 30, 3), row(:st_spatk, 50, 5),
                  row(:st_spdef, 60, 6), row(:st_speed, 40, 4)], PokeAccess::Summary.eviv_rows(pk)
  end

  test "lists them by the stat numbers an engine gives, in its order" do
    pk = Poke.build(:ev => EVS, :iv => IVS)
    reborn = [[0, :st_hp], [1, :st_atk], [2, :st_def], [3, :st_spatk], [4, :st_spdef], [5, :st_speed]]
    { reborn => [row(:st_hp, 10, 1), row(:st_atk, 20, 2), row(:st_def, 30, 3), row(:st_spatk, 40, 4),
                 row(:st_spdef, 50, 5), row(:st_speed, 60, 6)],
      [[3, :st_speed], [0, :st_hp]] => [row(:st_speed, 40, 4), row(:st_hp, 10, 1)] }.each do |rows, want|
      assert_equal want, PokeAccess::Summary.eviv_rows(pk, rows), "rows #{rows.inspect}"
    end
  end

  test "says 0 for a stat the engine leaves unset" do
    pk = Poke.build(:ev => [10, 20, 30, nil, 50, 60], :iv => [1, 2, 3, nil, 5, 6])
    assert_equal [row(:st_hp, 10, 1), row(:st_atk, 20, 2), row(:st_def, 30, 3), row(:st_spatk, 50, 5),
                  row(:st_spdef, 60, 6), row(:st_speed, 0, 0)], PokeAccess::Summary.eviv_rows(pk)
  end

  private

  # The row an EV and IV page says for the stat named key.
  def row(key, ev, iv)
    PokeAccess::I18n.t(:sm_eviv_row, :stat => PokeAccess::I18n.t(key), :ev => ev, :iv => iv)
  end
end
