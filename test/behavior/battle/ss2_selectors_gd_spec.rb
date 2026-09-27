# Soulstones 2's battle carousels (its edited Pokeball UI): the Poke Ball picker and the Quick party switch, rows of
# sprites under a painted caption, and their Yes/No question (pbShowCommandsUpper). Gamedata pass.

module Battle
  class Scene
    def pbSelectBallInfo(_idx, _pocket); :picked; end
    def pbUpdateBallSelection(_items, _index, _show_desc = false); :drawn; end
    def pbSelectPartyInfo(_idx, _can_cancel); :switched; end
    # Paints the row: the key hints and the focused member's caption, and with the extra panel a line per move.
    def pbUpdatePartySelection(party, index, show_desc = false)
      pk = party[index]
      caption = pk ? "#{pk.name} [Lv.#{pk.level}]" : "Return"
      pbDrawTextPositions(nil, [["USE: Switch", 50, 0], [show_desc ? "ACT: Summary" : "SPC: Extra", 400, 0], [caption, 256, 0]])
      drawTextEx(nil, 10, 0, 500, 2, "[+] Placaje [o]") if show_desc && pk
      :drawn
    end
    def pbShowCommandsUpper(_msg, _commands, _default, _show_desc); 0; end
    def pbPartySummary(_index, _party, _inbattle = false); :summary; end
  end
end

require File.expand_path("../../../games/soulstones2/battle_selectors", File.dirname(__FILE__))

Suite.define("ss2 battle carousels: the ball, the switch and its question are read") do
  t = PokeAccess::I18n
  scene = Battle::Scene.new
  items = [[nil], [:POKEBALL, 12], [:ULTRABALL, 3], [nil]]

  scene.pbSelectBallInfo(0, 3)
  scene.pbUpdateBallSelection(items, 1, false)
  eq "the focused ball with how many are left, queued as the picker opens", SpeakCapture.log,
     [[t.t(:dbk_ball, :name => "ItemPOKEBALL", :n => 12), false]]
  SpeakCapture.clear
  scene.pbUpdateBallSelection(items, 2, false)
  eq "moving along the row reads the next, interrupting", SpeakCapture.log,
     [[t.t(:dbk_ball, :name => "ItemULTRABALL", :n => 3), true]]
  SpeakCapture.clear
  scene.pbUpdateBallSelection(items, 2, true)
  match "the details toggle adds the description without a move", SpeakCapture.lines.join(" "), /idescULTRABALL/

  SpeakCapture.clear
  pika = Poke.build(:name => "Pika", :level => 20, :hp => 45, :totalhp => 60, :gender => 1)
  onix = Poke.build(:name => "Onix", :level => 22, :hp => 0, :totalhp => 70)
  party = [nil, pika, onix, nil]
  foes = [Struct.new(:index, :name).new(1, "Rival A"), Struct.new(:index, :name).new(3, "Rival B")]
  scene.instance_variable_set(:@battle, Struct.new(:allBattlers).new(foes))
  scene.pbSelectPartyInfo(0, true)
  scene.pbUpdatePartySelection(party, 1, false)
  eq "the caption as painted, what the bar shows, and the key hints as the row opens -- queued, so a row the "      "game opens by itself after a faint does not cut the battle lines before it", SpeakCapture.log,
     [["Pika [Lv.20], #{PokeAccess::Battle.hp_phrase(45, 60, true)}, USE: Switch, SPC: Extra", false]]
  SpeakCapture.clear
  scene.pbUpdatePartySelection(party, 2, false)
  eq "the next member, fainted, without the hints again, interrupting", SpeakCapture.log,
     [["Onix [Lv.22], #{t.t(:pk_fainted)}", true]]
  SpeakCapture.clear
  scene.pbUpdatePartySelection(party, 1, true)
  eq "the extra panel: each move's verdict on each foe, and the hints that changed with it", SpeakCapture.lines,
     ["Pika [Lv.20], #{PokeAccess::Battle.hp_phrase(45, 60, true)}, Placaje: "       "#{t.t(:mv_eff_vs, :name => "Rival A", :eff => t.t(:mv_eff_super))}, "       "#{t.t(:mv_eff_vs, :name => "Rival B", :eff => t.t(:mv_eff_neutral))}, USE: Switch, ACT: Summary"]
  SpeakCapture.clear
  scene.pbUpdatePartySelection(party, 3, true)
  eq "the way back at the end of the row", SpeakCapture.lines, ["Return"]

  SpeakCapture.clear
  scene.pbUpdatePartySelection(party, 1, true)
  scene.pbPartySummary(1, party, true)
  SpeakCapture.clear
  scene.pbUpdatePartySelection(party, 1, true)
  match "coming back from a member's summary says that member again", SpeakCapture.lines.join(" "), /\APika/

  SpeakCapture.clear
  eq "the question keeps its own answer", scene.pbShowCommandsUpper("Would you like to switch in Pika", %w[Yes No], 1, false), 0
  spoke "and is read before the Yes and No", /Would you like to switch in Pika/
end

Suite.define("ss2 battle carousels: the quick switch at the party reading's level") do
  scene = Battle::Scene.new
  pika = Poke.build(:name => "Pika", :level => 20, :hp => 45, :totalhp => 60)
  def pika.pokerusStage; 1; end
  party = [nil, pika]
  hp = PokeAccess::Battle.hp_phrase(45, 60, true)
  rows = vb_levels do
    scene.pbSelectPartyInfo(0, true)
    SpeakCapture.clear
    scene.pbUpdatePartySelection(party, 1, false)
    SpeakCapture.last
  end
  eq "brief: the name and the hit points, no level and no keys", rows[0], "Pika, #{hp}"
  eq "medium: the caption with its level, and the keys", rows[1], "Pika [Lv.20], #{hp}, USE: Switch, SPC: Extra"
  eq "full: and the Pokerus", rows[2],
     "Pika [Lv.20], #{hp}, #{PokeAccess::I18n.t(:pk_pokerus)}, USE: Switch, SPC: Extra"
end
