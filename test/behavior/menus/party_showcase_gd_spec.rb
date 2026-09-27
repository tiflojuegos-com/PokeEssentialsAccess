# Tectonic's Party Showcase, one painted page of the whole team, read as painted, once. The stand-in's constructor
# paints and runs one frame of the pollers in place of the real one's loop, where the opening read comes from. With a
# party it paints each member through renderShowcaseInfo, and the footer through writeBottomText, as the real one.
class PokemonPartyShowcase_Scene
  attr_accessor :footer
  def initialize(party, _snapshot = false, _name = nil)
    @party = party
    @footer = "Chapter 4"
    paint
    PokeAccess::Keys.run_frame_pollers
  end
  def updateShowcaseInfo(_update = false); paint; end
  def paint
    if @party.empty?
      pbDrawTextPositions(nil, [["Chispa", 0, 0], ["Nv. 25", 0, 20]])
    else
      @party.each_with_index { |pk, i| renderShowcaseInfo(i, pk) }
    end
    writeBottomText
  end
  def renderShowcaseInfo(index, pokemon, _refresh = true)
    y = index * 100
    drawTextEx(nil, 20, y, 200, 1, "#{pokemon.name} Lv. #{pokemon.level}")
    drawTextEx(nil, 202, y, 80, 1, "\xE2\x99\x82") if pokemon.gender == 0
    drawTextEx(nil, 78, y + 22, 200, 1, "Placaje")
    drawTextEx(nil, 10, y + 92, 200, 1, "Espesura")
    drawTextEx(nil, 224, y + 16, 80, 1, "252")
  end
  def writeBottomText
    drawFormattedTextEx(nil, 0, 40, 200, @footer)
  end
end

# The reader registered before this class existed, so this repo's plugins/party_showcase.rb is evaluated again.
eval(File.read(File.join(Harness::ROOT, "plugins", "party_showcase.rb")),
     TOPLEVEL_BINDING, File.join(Harness::ROOT, "plugins", "party_showcase.rb"))
require File.expand_path("../../../games/soulstones2/showcase", File.dirname(__FILE__))

Suite.define("party showcase: the page is read as painted, and a repaint that changed nothing is quiet") do
  SpeakCapture.clear
  scene = PokemonPartyShowcase_Scene.new([])
  line = SpeakCapture.lines.join(" ")
  match "the member painted is read, while the page is still up", line, /Chispa/
  falsy "and the screen is let go once the constructor's loop returns", PokeAccess::PartyShowcase.instance_variable_get(:@scene)
  match "with what the page says about it", line, /Nv. 25/
  match "and the footer too", line, /Chapter 4/

  SpeakCapture.clear
  scene.updateShowcaseInfo(true)
  silent "a repaint of the same page says nothing"

  scene.footer = "Chapter 5"
  SpeakCapture.clear
  scene.updateShowcaseInfo(true)
  match "and one that changed is read again", SpeakCapture.lines.join(" "), /Chapter 5/
end

# A value two members share (the same level or item) is read for each of them.
Suite.define("party showcase: a value two members share is read for both") do
  scene = PokemonPartyShowcase_Scene.new([])
  def scene.paint
    pbDrawTextPositions(nil, [["Chispa", 0, 0], ["Nv. 25", 0, 20], ["Brasa", 0, 60], ["Nv. 25", 0, 80]])
  end
  SpeakCapture.clear
  scene.footer = "otro estado"
  scene.updateShowcaseInfo(true)
  eq "both members keep their level", SpeakCapture.lines, ["Chispa, Nv. 25, Brasa, Nv. 25"]
end

# What each member shows only as icons or colours: the shiny star, the held item, the ball and the nature's shading
# of the stat values.
Suite.define("party showcase: each member's icons and nature shading are said with it") do
  t = PokeAccess::I18n
  nature = Object.new
  def nature.stat_changes; [[:ATTACK, 10], [:SPEED, -10]]; end
  shiny = Poke.build(:name => "Chispa", :level => 25, :shiny => true, :item => :ORANBERRY)
  shiny.instance_variable_set(:@nat, nature)
  def shiny.poke_ball; :ULTRABALL; end
  def shiny.nature_for_stats; @nat; end
  plain = Poke.build(:name => "Brasa", :level => 30, :gender => 1)
  def plain.poke_ball; :POKEBALL; end

  SpeakCapture.clear
  PokemonPartyShowcase_Scene.new([shiny, plain])
  line = SpeakCapture.lines.join(" ")
  icons = [t.t(:pk_shiny), t.t(:pk_holds, :item => PokeAccess::Data.item_name(:ORANBERRY)),
           t.t(:sum_ball, :b => PokeAccess::Data.item_name(:ULTRABALL))].join(", ")
  truthy "the shiny star, the item and the ball follow the name and sex sign",
         line.include?("Chispa Lv. 25, \xE2\x99\x82, #{icons}, Placaje")
  nat = t.t(:sm_nature_effect, :up => PokeAccess::Data.stat_name(:ATTACK),
            :down => PokeAccess::Data.stat_name(:SPEED)).sub(/\.\s*\z/, "")
  truthy "the nature's shading follows the member's stats", line.include?("252, #{nat}, Brasa Lv. 30")
  truthy "a member with no star, no item and a neutral nature has only its ball",
         line.include?("Brasa Lv. 30, #{t.t(:sum_ball, :b => PokeAccess::Data.item_name(:POKEBALL))}, Placaje")
end

# Soulstones 2 colours its footer's difficulty line against the difficulty the game was started on
# ($game_variables[985]): blue when raised, red when lowered.
Suite.define("party showcase: Soulstones 2's footer says whether the difficulty was raised or lowered") do
  t = PokeAccess::I18n
  def $player.difficulty_mode; @ss2_mode; end
  begin
    $game_variables[985] = "Standard"
    $player.instance_variable_set(:@ss2_mode, 2)
    SpeakCapture.clear
    PokemonPartyShowcase_Scene.new([])
    truthy "raised from Standard to Unfair, after the footer", SpeakCapture.lines.join(" ").end_with?("Chapter 4, #{t.t(:ss2_diff_raised)}")

    $game_variables[985] = "Unfair"
    $player.instance_variable_set(:@ss2_mode, 1)
    SpeakCapture.clear
    PokemonPartyShowcase_Scene.new([])
    truthy "lowered from Unfair to Adept", SpeakCapture.lines.join(" ").include?(t.t(:ss2_diff_lowered))

    $game_variables[985] = "Adept"
    SpeakCapture.clear
    PokemonPartyShowcase_Scene.new([])
    line = SpeakCapture.lines.join(" ")
    falsy "the difficulty the game started on keeps the page's colour", line.include?(t.t(:ss2_diff_raised)) || line.include?(t.t(:ss2_diff_lowered))
  ensure
    class << $player; remove_method :difficulty_mode; end
    $player.instance_variable_set(:@ss2_mode, nil)
  end
end
