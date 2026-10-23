# A gen-6 fight runs inside Scene_Map, and only some games mark it with $game_temp.in_battle, so its start and end mark
# it (Battle.in_battle?): the hold quiets the sonar meanwhile, the locator keys stay free, and its end drops its lines
# from the info key.
class SonarSilenceTest < PokeAccessTest
  test "is in battle from the battle's start to its end" do
    refute PokeAccess::Battle.in_battle?, "at rest"
    PokeAccess::Battle.battle_started
    assert PokeAccess::Battle.in_battle?, "once it starts"
    PokeAccess::Battle.battle_ended
    refute PokeAccess::Battle.in_battle?, "once it ends"
  end

  test "holds the cues for the battle while it runs, and lets go as it ends" do
    PokeAccess::Battle.battle_started
    assert_equal :battle, PokeAccess::Control.reason(:hold), "while it runs"
    PokeAccess::Battle.battle_ended
    assert_nil PokeAccess::Control.reason(:hold), "once it ends"
  end

  test "leaves the locator keys free during a battle" do
    PokeAccess::Battle.battle_started
    assert_nil PokeAccess::Control.reason(:keys)
  end

  test "stays in battle through the clear every map frame makes" do
    PokeAccess::Battle.battle_started
    PokeAccess::Battle.clear_battle
    assert PokeAccess::Battle.in_battle?
  end

  test "forgets the battle's move, foe and ready line on the info key as the fight ends" do
    [:move, :battle_foe, :text].each do |kind|
      PokeAccess::Battle.battle_started
      PokeAccess::Info.set_info(kind, nil, "Rattata, nivel 3")
      PokeAccess::Battle.battle_ended
      assert_nil PokeAccess::Info.row_text, "for #{kind}"
    end
  end

  test "keeps a Pokemon or an item on the info key as the fight ends" do
    [:pokemon, :item].each do |kind|
      PokeAccess::Battle.battle_started
      PokeAccess::Info.set_info(kind, nil, "Pikachu, nivel 12")
      PokeAccess::Battle.battle_ended
      assert_equal "Pikachu, nivel 12", PokeAccess::Info.row_text, "for #{kind}"
    end
  end
end
