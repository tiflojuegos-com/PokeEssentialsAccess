# poll_sprite_menu is the shared reader for sprite-driven menus (ready menu, Neo PauseMenu, the pokegear
# theme picker and the v22 pokegear): it polls @index over the entry list each frame and must speak the
# focused entry only when it changes, with the dedup state hung on the scene instance via Cursor. The dedup
# slot used to be passed WITH a leading @ (:@access_ready_last), which composed an illegal ivar name inside
# Cursor, made instance_variable_set raise into the silent rescue, and muted all four readers; slots are
# normalised now, so the legacy spelling must speak and dedup exactly like the bare one.
Suite.define("menus: poll_sprite_menu speaks on change and dedups on repeat") do
  scene = Object.new
  scene.instance_variable_set(:@commands, [[1, "Map"], [2, "Radio"]])
  scene.instance_variable_set(:@index, 0)
  3.times { PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :pg_last) { |e| (e[1] rescue nil) } }
  spoke_once "the focused entry is read exactly once while the cursor stays", /Map/

  SpeakCapture.clear
  scene.instance_variable_set(:@index, 1)
  3.times { PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :pg_last) { |e| (e[1] rescue nil) } }
  spoke_once "moving the cursor reads the new entry exactly once", /Radio/
  not_spoke "the previous entry is not repeated", /Map/

  SpeakCapture.clear
  fresh = Object.new
  fresh.instance_variable_set(:@commands, [[1, "Map"], [2, "Radio"]])
  fresh.instance_variable_set(:@index, 1)
  PokeAccess::Menus.poll_sprite_menu(fresh, :@commands, :pg_last) { |e| (e[1] rescue nil) }
  spoke "a fresh scene instance re-reads the same index (per-instance dedup)", /Radio/
end

# The legacy @-prefixed slot spelling (what the four readers shipped with, and what old game profiles may
# still pass) must keep working: this is the regression the illegal-ivar bug silently broke.
Suite.define("menus: poll_sprite_menu tolerates a legacy @-prefixed dedup slot") do
  scene = Object.new
  scene.instance_variable_set(:@commands, [[1, "Ready one"], [2, "Ready two"]])
  scene.instance_variable_set(:@index, 0)
  3.times { PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :@access_ready_last) { |e| (e[1] rescue nil) } }
  spoke_once "a legacy @ slot speaks the focused entry exactly once", /Ready one/

  SpeakCapture.clear
  scene.instance_variable_set(:@index, 1)
  3.times { PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :@access_ready_last) { |e| (e[1] rescue nil) } }
  spoke_once "a legacy @ slot reads the cursor move exactly once", /Ready two/
  not_spoke "a legacy @ slot does not repeat the previous entry", /Ready one/

  # Sharing has to be shown where the two spellings DISAGREE. Moving back to index 0 and reading once says
  # "Ready one" whether the slot is shared or separate -- in one world because the key changed, in the other
  # because the slot is empty. Asking the bare spelling to re-read the index the @ spelling just recorded is
  # the only probe that tells them apart: shared means silence.
  SpeakCapture.clear
  2.times { PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :access_ready_last) { |e| (e[1] rescue nil) } }
  not_spoke "the bare spelling shares the @ spelling's dedup state, so it repeats nothing", /Ready two/

  SpeakCapture.clear
  scene.instance_variable_set(:@index, 0)
  PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :access_ready_last) { |e| (e[1] rescue nil) }
  spoke_once "and still reads a real move through either spelling", /Ready one/
end
