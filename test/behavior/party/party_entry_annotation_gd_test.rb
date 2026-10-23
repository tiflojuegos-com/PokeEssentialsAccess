# The Battle Tower's entry screen annotates the member just picked ("not entered" turns into "first") with the cursor
# still on it, where no cursor move would say it: the annotation's change is said on its own.
class PartyEntryAnnotationGdTest < PokeAccessTest
  test "says the member again with its new annotation in place of its HP" do
    panel = selected_panel(Poke.build(:name => "Pika", :level => 20, :hp => 0, :totalhp => 50))
    SpeakCapture.clear
    panel.text = "PRIMERO"
    assert_equal [["#{PokeAccess::I18n.t(:pty_head, :name => "Pika, Species1", :sex => " \xE2\x99\x82", :level => 20)}, PRIMERO", true]],
                 SpeakCapture.log
  end

  test "says nothing when the annotation is set again to the same text" do
    panel = selected_panel(Poke.build(:name => "Pika", :level => 20))
    panel.text = "PRIMERO"
    SpeakCapture.clear
    panel.text = "PRIMERO"
    assert_nothing_spoken
  end

  test "says nothing of an annotation changing on a panel the cursor is not on" do
    other = PokemonPartyPanel.new(Poke.build(:name => "Otro"))
    SpeakCapture.clear
    other.text = "SEGUNDO"
    assert_nothing_spoken
  end

  test "says an egg's new annotation after the word egg" do
    egg = Poke.build(:name => "Pika")
    egg.define_singleton_method(:egg?) { true }
    panel = selected_panel(egg)
    SpeakCapture.clear
    panel.text = "PRIMERO"
    assert_equal [["#{PokeAccess::I18n.t(:pty_egg)}, PRIMERO", true]], SpeakCapture.log
  end

  test "stands down where the scene reports the cursor itself" do
    panel = selected_panel(Poke.build(:name => "Pika", :level => 20))
    SpeakCapture.clear
    ui = PokeAccess::UIV21
    was = ui.instance_variable_get(:@scene_reports)
    begin
      ui.instance_variable_set(:@scene_reports, true)
      panel.text = "PRIMERO"
    ensure
      ui.instance_variable_set(:@scene_reports, was)
    end
    assert_nothing_spoken
  end

  private

  # A panel of pk, annotated "not entered", with the cursor on it.
  def selected_panel(pk)
    panel = PokemonPartyPanel.new(pk)
    panel.text = "NO INSCRITO"
    panel.selected = true
    panel
  end
end
