# Soulstones 2's own databox icons, registered by its profile (games/soulstones2/battle_marks.rb) over the core's
# databox marks and read through the modern databox hook: a pinch ability at work and a wild foe's held item.
ss2_battle_marks = File.join(Harness::ROOT, "games", "soulstones2", "battle_marks.rb")
eval(Harness.source(ss2_battle_marks), TOPLEVEL_BINDING, ss2_battle_marks)

class Ss2BattleMarksGdTest < PokeAccessTest
  # A wild foe as its databox shows it.
  Foe = Struct.new(:index, :name, :pokemon)

  test "says a pinch ability at work and a held item as the foe comes in" do
    box_for(pidgey, %w[icon_pinch icon_item]).refresh
    marks = [PokeAccess::I18n.t(:ss2_mark_pinch), PokeAccess::I18n.t(:ss2_adv_holds)].join(", ")
    assert_equal [[PokeAccess::I18n.t(:bt_marks_entry, :name => "Pidgey", :marks => marks), false]], SpeakCapture.log
  end

  test "keeps each icon as the foe's mark, by its word, in the order drawn" do
    foe = pidgey
    box_for(foe, %w[icon_item icon_pinch]).refresh
    assert_equal [PokeAccess::I18n.t(:ss2_adv_holds), PokeAccess::I18n.t(:ss2_mark_pinch)],
                 PokeAccess::Battle.shown_marks(foe)
  end

  test "drops the marks once the box stops drawing them" do
    foe = pidgey
    box = box_for(foe, %w[icon_pinch icon_item])
    box.refresh
    box.extra = []
    box.refresh
    assert_equal [], PokeAccess::Battle.shown_marks(foe)
  end

  private

  # A wild Pidgey, the foe on the far side.
  def pidgey
    Foe.new(1, "Pidgey", Object.new)
  end

  # The foe's databox, drawing the given icons of the game's after the stock ones.
  def box_for(foe, icons)
    box = Battle::Scene::PokemonDataBox.new(foe)
    box.extra = icons
    box
  end
end
