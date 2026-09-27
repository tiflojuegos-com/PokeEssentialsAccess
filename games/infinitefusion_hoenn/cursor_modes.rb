# IF Hoenn's PC cursor modes (pbSetCursorMode: normal, multi-select), shown only by the arrow's picture: a change
# is said in the core's words for PC modes; setting the mode already on (as fusing does) is not.
PokeAccess::Game.define("ifh_cursor_modes") do
  around("PokemonStorageScene", :pbSetCursorMode, :optional => true) do |scene, nxt, _a|
    was = (PokeAccess.ivar(scene, :@cursormode) || "default").to_s
    ret = nxt.call
    now = (PokeAccess.ivar(scene, :@cursormode) || "default").to_s
    if now != was
      key = { "multiselect" => :pc_mode_multi, "quickswap" => :pc_mode_quick }[now] || :pc_mode_normal
      PokeAccess::StorageModes.say(scene, key)
    end
    ret
  end
end
