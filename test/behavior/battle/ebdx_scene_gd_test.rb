# Elite Battle: DX's databoxes, party lineups and capture Pokedex page (plugins/ebdx.rb): the marks a box shows by
# its sprites (the shiny name, the caught ball, the Mega, Primal, Ultra Burst, Dynamax, Alpha, Noble and Totem
# symbols), each side's balls as the lineup slides in, and the page a capture shows, read as painted.
require File.expand_path("ebdx_stand_ins", File.dirname(__FILE__))

class EbdxSceneGdTest < PokeAccessTest
  T = PokeAccess::I18n
  # A Pokemon as the databox asks it whether it is shiny.
  Mon = Struct.new(:shiny, :shadow) do
    def shiny?; shiny; end
    def shadowPokemon?; shadow ? true : false; end
  end

  test "a foe's box says the caught ball and the Mega symbol as the foe enters, queued, and keeps them" do
    foe = EbdxBattler.new(1, "Rattata")
    box(foe, false, "caught" => pic, "mega" => pic).refresh
    marks = [T.t(:dex_caught), T.t(:bt_mark_mega)]
    assert_equal [[T.t(:bt_marks_entry, :name => "Rattata", :marks => marks.join(", ")), false]], SpeakCapture.log
    assert_equal marks, PokeAccess::Battle.shown_marks(foe)
  end

  test "a shiny Shadow Pokemon, whose name Dark Horizon paints purple, says no shiny" do
    foe = EbdxBattler.new(1, "Mareep")
    DataBoxEBDX.new(foe, Mon.new(true, true), "caught" => pic).refresh
    assert_equal [T.t(:dex_caught)], PokeAccess::Battle.shown_marks(foe)
  end

  test "the shiny gold of the name and the Primal symbol are marks too" do
    foe = EbdxBattler.new(1, "Groudon")
    foe.primal = true
    box(foe, true, "mega" => pic).refresh
    assert_equal [T.t(:pk_shiny), T.t(:bt_mark_primal)], PokeAccess::Battle.shown_marks(foe)
  end

  test "the Ultra Burst and Dynamax symbols of ZUD's patch are marks" do
    foe = EbdxBattler.new(3, "Necrozma")
    box(foe, false, "ultra" => pic, "dynamax" => pic, "caught" => EbdxSprite.new).refresh
    assert_equal [T.t(:bt_m_ultra), T.t(:bt_m_dynamax)], PokeAccess::Battle.shown_marks(foe)
  end

  test "the Alpha, Noble and Totem symbols Golden Crown's patch adds are marks, and a sprite holding none is none" do
    foe = EbdxBattler.new(1, "Kleavor")
    box(foe, false, "caught" => pic, "alpha" => pic, "noble" => pic, "totem" => EbdxSprite.new).refresh
    marks = [T.t(:dex_caught), T.t(:bt_m_alpha), T.t(:bt_m_noble)]
    assert_equal [[T.t(:bt_marks_entry, :name => "Kleavor", :marks => marks.join(", ")), false]], SpeakCapture.log
    other = EbdxBattler.new(3, "Mimikyu")
    box(other, false, "totem" => pic).refresh
    assert_equal [T.t(:bt_m_totem)], PokeAccess::Battle.shown_marks(other)
  end

  test "a refresh for the same foe says nothing again, and the player's box says nothing" do
    foe = EbdxBattler.new(1, "Rattata")
    b = box(foe, false, "caught" => pic)
    b.refresh
    SpeakCapture.clear
    b.refresh
    mine = EbdxBattler.new(0, "Pikachu")
    box(mine, true, {}).refresh
    assert_nothing_spoken
    assert_equal [T.t(:pk_shiny)], PokeAccess::Battle.shown_marks(mine)
  end

  test "a box not yet set up keeps no marks" do
    foe = EbdxBattler.new(1, "Rattata")
    b = box(foe, false, "caught" => pic)
    b.instance_variable_set(:@loaded, false)
    b.refresh
    assert_nothing_spoken
    assert_equal [], PokeAccess::Battle.shown_marks(foe)
  end

  test "the player's lineup counts its balls as drawn, queued" do
    party = [EbdxMember.new(20), EbdxMember.new(5), EbdxMember.new(9, :POISON), EbdxMember.new(0),
             EbdxMember.new(1, :NONE, true), nil]
    PartyLineupEBDX.new(EbdxBattle.new([], 1, [party, []]), 0).refresh
    list = [T.t(:ura_balls_ok, :n => 2), T.t(:ura_balls_status, :n => 1), T.t(:ura_balls_fainted, :n => 2)].join(", ")
    assert_equal [[T.t(:ura_balls_mine, :list => list), false]], SpeakCapture.log
  end

  test "the foe's lineup is the foe's team, and only the six balls drawn count" do
    party = Array.new(7) { EbdxMember.new(10) }
    PartyLineupEBDX.new(EbdxBattle.new([], 1, [[], party]), 1).refresh
    assert_equal [T.t(:ura_balls_foe, :list => T.t(:ura_balls_ok, :n => 6))], SpeakCapture.lines
  end

  test "the trainer sliding in to speak leads its next line by name" do
    scene_with_trainers.pbShowOpponent(1, true)
    PokeAccess.say_dialogue("¡No me rendiré!")
    PokeAccess.say_dialogue("Sigue luchando.")
    assert_equal [["Victor: ¡No me rendiré!", false], ["Sigue luchando.", false]], SpeakCapture.log
  end

  test "the trainer shown for its lose text leads it too" do
    scene_with_trainers.pbShowOpponent(0)
    PokeAccess.say_dialogue("Has ganado.")
    assert_equal ["Lyssa: Has ganado."], SpeakCapture.lines
  end

  test "a picture shown by file name, or an index past the trainers, leads nothing" do
    scene = scene_with_trainers
    scene.pbShowOpponent(0, true, "RIVAL")
    scene.pbShowOpponent(2)
    PokeAccess.say_dialogue("Hola.")
    assert_equal ["Hola."], SpeakCapture.lines
  end

  test "a capture's Pokedex page is read as painted, in reading order, with its types, queued" do
    EliteBattle_Pokedex.new(:PIKACHU)
    rows = ["025 Pikachu", "Mouse Pokémon", T.t(:pdx_type, :t => "TypeTYPE1"), "Height", "0.4 m", "Weight", "6.0 kg",
            EliteBattle_Pokedex::ENTRY]
    assert_equal [[rows.join(", "), false]], SpeakCapture.log
  end

  test "the capture page's details follow the Pokedex page reading's levels" do
    said = vb_levels do
      SpeakCapture.clear
      EliteBattle_Pokedex.new(:PIKACHU)
      SpeakCapture.last
    end
    assert_equal "025 Pikachu", said[0]
    assert_equal "025 Pikachu, Mouse Pokémon, #{T.t(:pdx_type, :t => 'TypeTYPE1')}", said[1]
  end

  private

  # A picture a databox sprite holds.
  def pic
    EbdxSprite.new(:picture)
  end

  # A databox, set up, for battler, its Pokemon shiny or not, holding sprites.
  def box(battler, shiny, sprites)
    DataBoxEBDX.new(battler, Mon.new(shiny), sprites)
  end

  # A battle scene against two trainers, Lyssa and Victor.
  def scene_with_trainers
    trainer = Struct.new(:name)
    scene = Battle::Scene.new
    trainers = [trainer.new("Lyssa"), trainer.new("Victor")]
    scene.instance_variable_set(:@battle, EbdxBattle.new([], 2, [[], []], trainers))
    scene
  end
end
