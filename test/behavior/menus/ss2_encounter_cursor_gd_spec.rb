# Soulstones 2's Encounter List UI adds a cursor over the species icons: the profile reads the species each move
# lands on (the shared reader reads a whole page). Action shows or hides a layer of type icons over the species, ??
# over one not caught. Gamedata pass. The stand-in is defined once and the profile loaded once, its hooks staying on
# this class, which each suite puts under the game's name.
class SS2EncTypeIcon
  attr_accessor :visible
  def initialize; @visible = false; end
end

class SS2EncounterScene
  attr_accessor :script, :uncaught
  attr_reader :enc_calls
  def initialize(enc)
    @enc = enc
    @index = 0
    @idx = 0
    @script = []
    @uncaught = []
    @sprites = {}
    enc.length.times { |i| @sprites["type1_#{i}"] = SS2EncTypeIcon.new }
  end
  # The game's own getEncData walks every species it has, so the stand-in counts the calls.
  def getEncData
    @enc_calls = (@enc_calls || 0) + 1
    [@enc, :Land]
  end
  def pbMoveDexSel; :moved; end
  def move(i); @idx = i; pbMoveDexSel; end
  # As the game's loop: a frame, then the key's effect. Action flips every type icon, a page change hides them all
  # and puts the cursor on the first species, and the redraw after a Demonic Eye battle (drawPresent) hides those of
  # the species not caught.
  def pbEncounter
    @script.each do |step|
      PokeAccess::Keys.run_frame_pollers
      case step
      when :action then @sprites.each_value { |s| s.visible = !s.visible }
      when :page
        @index += 1
        @idx = 0
        @sprites.each_value { |s| s.visible = false }
      when :redraw then @uncaught.each { |i| @sprites["type1_#{i}"].visible = false }
      else move(step)
      end
    end
    PokeAccess::Keys.run_frame_pollers
    :closed
  end
end

module SS2EncounterSpec
  def self.with_scene_class
    saved = Object.const_defined?(:EncounterList_Scene) ? EncounterList_Scene : nil
    Object.send(:remove_const, :EncounterList_Scene) if saved
    Object.const_set(:EncounterList_Scene, SS2EncounterScene)
    unless @loaded
      @loaded = true
      load File.expand_path("../../../games/soulstones2/encounter_cursor.rb", File.dirname(__FILE__))
    end
    yield
  ensure
    Object.send(:remove_const, :EncounterList_Scene)
    Object.const_set(:EncounterList_Scene, saved) if saved
  end
end

Suite.define("ss2 encounter list: the species cursor reads the species it lands on") do
  SS2EncounterSpec.with_scene_class do
    scene = EncounterList_Scene.new([:PIKACHU, :RATTATA])
    eq "the move keeps its own return", scene.move(1), :moved
    eq "the species with its dex status and where it sits", SpeakCapture.lines,
       ["#{PokeAccess::EncounterList.entry_text(:RATTATA)}, #{PokeAccess::I18n.t(:list_pos, :i => 2, :n => 2)}"]
    eq "the info key keeps the species with its state", PokeAccess::Info.info_text,
       PokeAccess::EncounterList.entry_text(:RATTATA, true)
    SpeakCapture.clear
    scene.move(1)
    silent "the same species again says nothing"
    scene.move(0)
    SpeakCapture.clear
    scene.move(-1)
    eq "the game's -1 (JumpUp after a page change) is the last species, as its confirm takes it", SpeakCapture.lines,
       ["#{PokeAccess::EncounterList.entry_text(:RATTATA)}, #{PokeAccess::I18n.t(:list_pos, :i => 2, :n => 2)}"]
  end
end

Suite.define("ss2 encounter list: Action's type layer is said, and the cursor adds the types while it is up") do
  SS2EncounterSpec.with_scene_class do
    t = PokeAccess::I18n
    entry = lambda { |sp| PokeAccess::EncounterList.entry_text(sp) }
    types = t.t(:pc_types, :t => PokeAccess::Data.type_name(:TYPE1))
    scene = EncounterList_Scene.new([:PIKACHU, :RATTATA])
    scene.script = [:action, 1, :action, :action, :page]
    SpeakCapture.clear
    eq "the loop keeps its own return", scene.pbEncounter, :closed
    eq "on, with the focused species' types; the cursor with them; off; on again; and off with a page change, queued",
       SpeakCapture.log,
       [["#{t.t(:ss2_enc_types_on)}. #{entry.call(:PIKACHU)}, #{types}", true],
        ["#{entry.call(:RATTATA)}, #{types}, #{t.t(:list_pos, :i => 2, :n => 2)}", true],
        [t.t(:ss2_enc_types_off), true],
        ["#{t.t(:ss2_enc_types_on)}. #{entry.call(:RATTATA)}, #{types}", true],
        [t.t(:ss2_enc_types_off), false]]
    eq "the info key keeps the types the layer showed", PokeAccess::Info.info_text,
       "#{PokeAccess::EncounterList.entry_text(:RATTATA, true)}, #{types}"
    eq "the page's species are asked for once per page, not on every frame", scene.enc_calls, 2

    dex = $player.pokedex
    def dex.owned?(_s); false; end
    begin
      eq "a species not caught shows the ?? icon, said as unknown", PokeAccess::SS2EncounterTypes.types(:MEWTWO),
         t.t(:pc_types, :t => t.t(:pdx_unknown_short))
    ensure
      class << dex; remove_method :owned?; end
    end
  end
end

# The redraw after a Demonic Eye battle leaves the layer over the caught species only, so each species is said with
# the icons over it, and moving between a covered one and a bare one is no switch of the layer.
Suite.define("ss2 encounter list: the cursor reads the types off the focused species' own icons") do
  SS2EncounterSpec.with_scene_class do
    t = PokeAccess::I18n
    entry = lambda { |sp| PokeAccess::EncounterList.entry_text(sp) }
    types = t.t(:pc_types, :t => PokeAccess::Data.type_name(:TYPE1))
    scene = EncounterList_Scene.new([:PIKACHU, :RATTATA])
    scene.uncaught = [1]
    scene.script = [:action, :redraw, 1, 0]
    SpeakCapture.clear
    scene.pbEncounter
    eq "the layer goes up; the bare species is said without types; the cursor moves say no switch", SpeakCapture.log,
       [["#{t.t(:ss2_enc_types_on)}. #{entry.call(:PIKACHU)}, #{types}", true],
        ["#{entry.call(:RATTATA)}, #{t.t(:list_pos, :i => 2, :n => 2)}", true],
        ["#{entry.call(:PIKACHU)}, #{types}, #{t.t(:list_pos, :i => 1, :n => 2)}", true]]
  end
end
