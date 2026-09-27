# Tutor.net's party half, a grid of panel sprites with its own pbChangeSelection: each panel's icon tint, whether its
# member can learn the move (pkmn_comp: 1 can, 2 cannot, 3 already knows it), is put into words.
class PokemonTutorNet_Scene
  attr_reader :sprites
  attr_accessor :activecmd
  def initialize(party, comps)
    @party = party
    @activecmd = 0
    @sprites = {}
    party.each_with_index do |_pk, i|
      panel = Object.new
      panel.instance_variable_set(:@c, comps[i])
      def panel.pkmn_comp; @c; end
      def panel.comp=(v); @c = v; end
      @sprites["pokemon#{i}"] = panel
    end
    @sprites["commands"] = Struct.new(:index, :commands).new(0, ["Placaje", "Rayo", "Surf"])
  end
  def pbChangeSelection(_key, currentsel); @activecmd = currentsel; end
  def pbChoosePokemon; @activecmd = @last_mon_index || 0; :picked; end
  attr_writer :last_mon_index
  def update_indicators(_move_list = nil); :drawn; end
  def set_comp(i, v); @sprites["pokemon#{i}"].comp = v; end
  def pbSetCommands(commands, index); @sprites["commands"].commands = commands; @sprites["commands"].index = index; end

  # The move list's loop: each step is one frame's tints on the grid and, where given, the move the list is on.
  def pbScene(steps, moves = nil)
    steps.each_with_index do |comps, n|
      @sprites["commands"].index = moves[n] if moves
      comps.each_with_index { |c, i| set_comp(i, c) }
      update_indicators
    end
    :chosen
  end
end
require File.expand_path("../../../games/soulstones2/tutor_net", File.dirname(__FILE__))
require File.expand_path("../../../games/soulstones2/own_tts", File.dirname(__FILE__))

Suite.define("soulstones 2 tutor: each party panel says whether it can learn the move") do
  a = Poke.build(:name => "Chispa")
  b = Poke.build(:name => "Brasa")
  scene = PokemonTutorNet_Scene.new([a, b], [1, 2])

  SpeakCapture.clear
  scene.pbChangeSelection(nil, 0)
  eq "the member by its name, as the game's own speech says it -- the grid draws no sign, level or hit " \
     "points -- then the tint put into words", SpeakCapture.lines, ["Chispa, #{PokeAccess::I18n.t(:tut_can)}"]

  SpeakCapture.clear
  scene.pbChangeSelection(nil, 1)
  match "the next panel says its own verdict", SpeakCapture.lines.join(" "),
        /#{PokeAccess::I18n.t(:tut_cannot)}/

  SpeakCapture.clear
  scene.pbChangeSelection(nil, 1)
  silent "and standing still says nothing"

  scene.last_mon_index = 1
  SpeakCapture.clear
  eq "the grid keeps its own return", scene.pbChoosePokemon, :picked
  eq "entering the grid says the member it lands on, the one chosen last, even if it was the last one said",
     SpeakCapture.lines, ["Brasa, #{PokeAccess::I18n.t(:tut_cannot)}"]
end

# Browsing the move list repaints the tints: who each move suits is said, queued after the move's name.
Suite.define("soulstones 2 tutor: browsing the moves says who each one suits, after its name") do
  t = PokeAccess::I18n
  a = Poke.build(:name => "Chispa")
  b = Poke.build(:name => "Brasa")
  c = Poke.build(:name => "Roca")
  scene = PokemonTutorNet_Scene.new([a, b, c], [0, 0, 0])

  SpeakCapture.clear
  scene.set_comp(0, 1)
  scene.update_indicators
  silent "the repaint before the list opens says nothing"

  SpeakCapture.clear
  eq "the list keeps its own return", scene.pbScene([[1, 2, 3], [1, 2, 3], [2, 2, 2]]), :chosen
  eq "each move that changes the tints says who can learn it and who knows it, queued, once",
     SpeakCapture.log,
     [[t.t(:tut_can_list, :names => "Chispa") + ". " + t.t(:tut_knows_list, :names => "Roca"), false],
      [t.t(:tut_nobody), false]]

  SpeakCapture.clear
  scene.pbScene([[2, 2, 2], [2, 2, 2], [2, 2, 2]], [0, 0, 1])
  eq "two moves in a row with the same tints are two answers", SpeakCapture.lines, [t.t(:tut_nobody), t.t(:tut_nobody)]
end

# Filtering by a member repaints the tints in the window about to close: that window is left to no reader, so the
# reopened list says its first move and tints once.
Suite.define("soulstones 2 tutor: filtering by a member says the new list's first move and its tints once") do
  scene = PokemonTutorNet_Scene.new([Poke.build(:name => "Chispa")], [1])
  PokeAccess::SS2TutorNet.browsing do
    SpeakCapture.clear
    scene.pbSetCommands(["Rayo"], 0)
    scene.update_indicators(["RAYO"])
    silent "the tints repainted for the list about to be replaced say nothing"
    truthy "and the window about to close is left to no reader", PokeAccess.dedicated?(scene.sprites["commands"])
  end
end

# With the game's own screen reader on (Reborn TextToSpeech, TTS_ENABLED), the player is told once of two voices.
Suite.define("soulstones 2: two voices at once are reported, once, and only when there really are two") do
  had = Object.const_defined?(:TTS_ENABLED)
  begin
    PokeAccess::SS2OwnTTS.forget
    Object.const_set(:TTS_ENABLED, false) unless had
    SpeakCapture.clear
    PokeAccess::SS2OwnTTS.warn_once
    silent "with the game's reader off there is nothing to warn about"

    PokeAccess::SS2OwnTTS.forget
    Object.send(:remove_const, :TTS_ENABLED)
    Object.const_set(:TTS_ENABLED, true)
    SpeakCapture.clear
    PokeAccess::SS2OwnTTS.warn_once
    eq "with it on the player is told, and told what to edit",
       SpeakCapture.lines, [PokeAccess::I18n.t(:ss2_two_voices)]

    SpeakCapture.clear
    PokeAccess::SS2OwnTTS.warn_once
    silent "and only once, not on every map change"
  ensure
    Object.send(:remove_const, :TTS_ENABLED) if Object.const_defined?(:TTS_ENABLED)
    PokeAccess::SS2OwnTTS.forget
  end
end
