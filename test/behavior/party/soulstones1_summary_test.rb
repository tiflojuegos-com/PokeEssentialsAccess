# Soulstones' five-page summary (games/soulstones1/summary.rb): the core's page 4 is read as its EVs/IVs page, with
# the ability it names under the rows and the description written below, and the core's page 5 as the moves.

# Only the profile's module is evaluated: its override of the shared summary belongs to the Soulstones process.
soulstones1_summary_path = File.join(Harness::ROOT, "games", "soulstones1", "summary.rb")
eval(Harness.source(soulstones1_summary_path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING,
     soulstones1_summary_path)

class Soulstones1SummaryTest < PokeAccessTest
  T = PokeAccess::I18n
  Page = PokeAccess::Soulstones1Summary
  Move = Struct.new(:id, :pp, :totalpp)

  test "the EVs/IVs page says its title, each stat's EV and IV in the order painted, then the ability" do
    with_ability_descriptions { assert_equal eviv_page, Page.eviv_text(eviv_mon) }
  end

  test "the ability is said with the description the page writes under its name" do
    with_ability_descriptions { assert_equal ability, Page.ability_text(eviv_mon) }
  end

  test "a Pokemon with no ability ends the page at its rows" do
    pk = Poke.build(:ev => [0, 0, 0, 0, 0, 0], :iv => [1, 2, 3, 4, 5, 6], :ability => 0)
    rows = [row(:st_hp, 0, 1), row(:st_atk, 0, 2), row(:st_def, 0, 3), row(:st_spatk, 0, 5), row(:st_spdef, 0, 6),
            row(:st_speed, 0, 4)]
    assert_equal "#{T.t(:ss1_sum_eviv)}. #{rows.join('. ')}", Page.eviv_text(pk)
  end

  test "a Pokemon it cannot read gives no page, not half of one" do
    assert_nil Page.eviv_text(nil)
  end

  test "the core's page 4 is read as the EVs/IVs page and its page 5 as the moves" do
    with_ability_descriptions do
      four = [World.stub_scene, eviv_mon, 4, "the stock page four"]
      five = [World.stub_scene, eviv_mon, 5, "the stock page five"]
      Page.repage(four)
      Page.repage(five)
      moves = T.t(:sm_moves, :list => "Mov33. #{T.t(:mv_type, :t => 'Tipo1')}. #{T.t(:mv_pp, :pp => 35, :tot => 35)}")
      assert_equal [eviv_page, moves], [four[3], five[3]]
    end
  end

  test "the other pages keep the text the core read" do
    [1, 2, 3, 6, :egg].each do |page|
      args = [World.stub_scene, eviv_mon, page, "as the core read it"]
      Page.repage(args)
      assert_equal "as the core read it", args[3], "page #{page.inspect}"
    end
  end

  private

  # A Pokemon with distinct EVs and IVs (PBStats order: HP, Attack, Defense, Speed, Sp. Atk, Sp. Def), ability 65 and
  # one move, Mov33, its PP full.
  def eviv_mon
    Poke.build(:ev => [4, 252, 0, 6, 0, 248], :iv => [31, 30, 29, 28, 27, 26], :ability => 65,
               :moves => [Move.new(33, 35, 35)])
  end

  # eviv_mon's EVs/IVs page: the title, each stat's row in the order painted (speed last), then the ability.
  def eviv_page
    rows = [row(:st_hp, 4, 31), row(:st_atk, 252, 30), row(:st_def, 0, 29), row(:st_spatk, 0, 27),
            row(:st_spdef, 248, 26), row(:st_speed, 6, 28)]
    "#{T.t(:ss1_sum_eviv)}. #{(rows + [ability]).join('. ')}"
  end

  # eviv_mon's ability as the page names it, with the description it writes under the name.
  def ability
    T.t(:sum_ability_desc, :a => "Habilidad65", :d => "msg65")
  end

  # One stat's row of the page: its name, EV and IV.
  def row(key, ev, iv)
    T.t(:sm_eviv_row, :stat => T.t(key), :ev => ev, :iv => iv)
  end

  # Runs the block with the ability description table the gen-6 data reads, which the engine stub lacks.
  def with_ability_descriptions
    had = MessageTypes.const_defined?(:AbilityDescs)
    MessageTypes.const_set(:AbilityDescs, 7) unless had
    yield
  ensure
    MessageTypes.send(:remove_const, :AbilityDescs) unless had
  end
end
