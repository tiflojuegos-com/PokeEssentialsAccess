# The Type Match-up chart (SpeciesTypeMatch_Scene, from the edited Type Match-up UI): a grid of coloured type
# icons that was WRITTEN for a screen reader -- it announces itself through Kernel.tts -- but ships with that
# reader off (TTS_ENABLED = false). While the chart is up, whatever the game hands to tts is spoken, and the
# Control key, which the flag disabled, is given back by calling the screen's own full read.
module PokeAccess
  module SS2TypeChart
    @live = nil

    # Whether the chart is the screen running now, which is the only place the relay speaks.
    def self.live; @live; end
    def self.enter(scene); @live = scene; end
    def self.leave; @live = nil; end

    # One line the game handed to its own reader.
    def self.relay(text)
      return unless @live
      PokeAccess.speak_clean(text, false)
    rescue StandardError
      nil
    end

    # The full match-up on demand, by calling the screen's own reader with the flag it asks for.
    def self.read_full(scene)
      return unless (Input.trigger?(Input::CTRL) rescue false)
      list = PokeAccess.ivar(scene, :@species)
      idx = PokeAccess.ivar(scene, :@index).to_i
      sp = (list[idx] rescue nil)
      scene.drawSpeciesTypes(sp, true) if sp
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  around("SpeciesTypeMatch_Scene", :pbTypeMatchUp, :optional => true) do |scene, nxt, _a|
    PokeAccess::SS2TypeChart.enter(scene)
    begin
      nxt.call
    ensure
      PokeAccess::SS2TypeChart.leave
    end
  end

  # pbUpdate is this screen's per-frame call, which is where a key press can be noticed without touching
  # its loop.
  after("SpeciesTypeMatch_Scene", :pbUpdate, :optional => true) do |scene, _r, _a|
    PokeAccess::SS2TypeChart.read_full(scene)
  end
end

# The relay itself. Global rather than per-scene because tts is a top-level function, and it says nothing
# unless the chart is the screen running -- the game calls it from a hundred and ten places, most of them
# on screens the mod already reads in the player's own language.
PokeAccess::Hooks.wrap_global("tts", "ss2_tts_relay", :before) do |args, _r|
  PokeAccess::SS2TypeChart.relay(args[0])
end
