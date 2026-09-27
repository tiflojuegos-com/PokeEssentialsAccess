# Infinite Fusion Hoenn's PC cursor modes (pbSetCursorMode), shown only by the arrow's picture: a change is said,
# setting the mode the scene is already in is not.

# The method as the game's scene has it: the mode kept in @cursormode, which starts at "default".
class PokemonStorageScene
  def pbSetCursorMode(value); @cursormode = value; end
end

# Hooks bind at load to the methods that exist then: the profile's file is loaded again over the stub above.
verbose = $VERBOSE
begin
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "cursor_modes.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

Suite.define("infinite fusion hoenn: the PC's cursor mode is said when it changes, and only then") do
  t = PokeAccess::I18n
  scene = PokemonStorageScene.new
  scene.instance_variable_set(:@cursormode, "default")
  SpeakCapture.clear
  scene.pbSetCursorMode("default")
  silent "setting the mode it is already in says nothing"
  scene.pbSetCursorMode("multiselect")
  eq "multi-select, when it comes", SpeakCapture.lines, [t.t(:pc_mode_multi)]
  SpeakCapture.clear
  scene.pbSetCursorMode("default")
  eq "and the normal mode on the way back", SpeakCapture.lines, [t.t(:pc_mode_normal)]
end
