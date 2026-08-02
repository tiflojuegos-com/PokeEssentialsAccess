# Spatial.earcon: the named non-positional cue vocabulary. A name must resolve through EARCONS to its
# file and default pitch, an explicit pitch must override the default (the minigame tick), zero volume
# must stay silent (cue's contract), and an unknown name must be a safe no-op.
Suite.define("spatial: earcon resolves names, honours pitch override, skips silence") do
  played = []
  Audio.instance_eval do
    (class << self; self; end).send(:define_method, :se_play) { |*a| played << a }
  end
  begin
    PokeAccess::Spatial.earcon(:radar_blip, 40)
    eq "one cue played", played.length, 1
    truthy "radar_blip resolves to its file", played[0][0].include?("pa_guide_c")
    eq "table volume passed through", played[0][1], 40
    eq "table default pitch used", played[0][2], 150

    played.clear
    PokeAccess::Spatial.earcon(:minigame_tick, 60, 123)
    truthy "minigame_tick resolves to its file", played[0][0].include?("pa_mg_tick")
    eq "an explicit pitch overrides the table default", played[0][2], 123

    played.clear
    PokeAccess::Spatial.earcon(:radar_blip, 0)
    eq "zero volume plays nothing", played.length, 0
    PokeAccess::Spatial.earcon(:no_such_earcon, 50)
    eq "an unknown name is a silent no-op", played.length, 0
  ensure
    Audio.instance_eval do
      (class << self; self; end).send(:define_method, :se_play) { |*a| }
    end
  end
end
