# Back on the modern party list after a command, the choice loop says the member or button under the cursor (or the
# member it is told to start on), queued; not on the opening's own choice, nor a member already said on the way back.
class PartyRetakeGdTest < PokeAccessTest
  BUTTON = Settings::MAX_PARTY_SIZE

  test "says the member under the cursor again, queued, back on the list after a command" do
    scene = back_on_list(1)
    scene.pbChoosePokemon
    assert_equal [[eevee_line, false]], SpeakCapture.log
  end

  test "says the button under the cursor again, queued, back on the list" do
    scene = back_on_list(BUTTON)
    scene.pbChoosePokemon
    assert_equal [[PokeAccess::I18n.t(:pc_cancel), false]], SpeakCapture.log
  end

  test "says nothing on the opening's own choice" do
    PokeAccess::UIV21.party_choice_done
    scene = PokemonParty_Scene.new(party)
    scene.pbStartScene
    SpeakCapture.clear
    scene.pbChoosePokemon(false, 0)
    assert_nothing_spoken
  end

  test "says nothing of a member the screen already said on the way back" do
    scene = back_on_list(1)
    scene.pbSelect(0)
    SpeakCapture.clear
    scene.pbChoosePokemon
    assert_nothing_spoken
  end

  test "says the member a choice is told to start on, not the one under the cursor" do
    { 0 => [1, pika_line], 1 => [0, eevee_line] }.each do |start, (cursor, want)|
      scene = back_on_list(cursor)
      scene.pbChoosePokemon(true, start)
      assert_equal [[want, false]], SpeakCapture.log, "told to start on #{start}"
    end
  end

  test "sets the member it says again for the info key" do
    scene = back_on_list(1)
    PokeAccess::Info.set_info(:text, "Datos", "Datos")
    scene.pbChoosePokemon
    assert_equal eevee_line, PokeAccess::Info.row_text
  end

  test "stands down where the scene reports the cursor itself" do
    scene = back_on_list(1)
    ui = PokeAccess::UIV21
    was = ui.instance_variable_get(:@scene_reports)
    begin
      ui.instance_variable_set(:@scene_reports, true)
      scene.pbChoosePokemon
    ensure
      ui.instance_variable_set(:@scene_reports, was)
    end
    assert_nothing_spoken
  end

  private

  # Pika and Eevee.
  def party
    [Poke.build(:name => "Pika", :level => 20), Poke.build(:name => "Eevee", :level => 5)]
  end

  # Pika's line as its panel says it, the species its icon shows after the nickname.
  def pika_line
    PokeAccess::I18n.t(:pty_member, :name => "Pika, Species1", :sex => " \xE2\x99\x82", :level => 20, :hp => 40, :tot => 40)
  end

  # Eevee's line as its panel says it, the species its icon shows after the nickname.
  def eevee_line
    PokeAccess::I18n.t(:pty_member, :name => "Eevee, Species1", :sex => " \xE2\x99\x82", :level => 5, :hp => 40, :tot => 40)
  end

  # A party screen opened on its first member, whose first choice the player made with the cursor moved to cursor
  # before a command took them off the list; the speech starts empty.
  def back_on_list(cursor)
    scene = PokemonParty_Scene.new(party)
    scene.on_start = lambda { scene.move_cursor(0) }
    scene.pbStartScene
    scene.on_choose = lambda { scene.move_cursor(cursor) }
    scene.pbChoosePokemon
    scene.on_choose = nil
    SpeakCapture.clear
    scene
  end
end
