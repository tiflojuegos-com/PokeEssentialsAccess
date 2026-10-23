# PokéLiberty's simple panel menus (plugins/menu_panels.rb, MenuPanel1/MenuPanel2): each panel's first painted frame
# read once, in the order the script writes it, a locked caption's "???" said as unknown; only while a panel runs.
class MenuPanelsTest < PokeAccessTest
  test "a panel's first frame is read once, locked captions as unknown and none dropped as repeats" do
    PokeAccess::MenuPanels.showing do
      ["Panel 1", "3 / X", "Texto 1", "???", "???"].each { |s| PokeAccess::PaintCapture.note(s, :positions, 0, 0) }
      PokeAccess::MenuPanels.poll
      PokeAccess::PaintCapture.note("Panel 1", :positions, 0, 0)
      PokeAccess::MenuPanels.poll
    end
    unknown = PokeAccess::DexEntry.unknown_marks("???")
    text = PokeAccess::PaintCapture.text(["Panel 1", "3 / X", "Texto 1", unknown, unknown], false)
    assert_equal [[PokeAccess::Verbosity.with_hint(text, PokeAccess::I18n.t(:mpanel_hint)), true]], SpeakCapture.log
  end

  test "before the panel paints, nothing is said, and the capture goes with the panel" do
    PokeAccess::MenuPanels.showing { PokeAccess::MenuPanels.poll }
    refute PokeAccess::PaintCapture.armed?(PokeAccess::MenuPanels::TAG), "no capture left armed for other screens"
    assert_nothing_spoken
  end

  test "outside a panel, paint caught under its tag is not said" do
    PokeAccess::PaintCapture.arm(PokeAccess::MenuPanels::TAG)
    PokeAccess::PaintCapture.note("7", :positions, 0, 0)
    PokeAccess::MenuPanels.poll
    PokeAccess::PaintCapture.take(PokeAccess::MenuPanels::TAG)
    assert_nothing_spoken
  end
end
