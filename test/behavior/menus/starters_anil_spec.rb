# Anil's starter menu (plugins/misc_scripts_anil.rb): the title the menu paints while it builds is said before the
# focused region when the selection opens, after the caller's message. The scene is reduced to the calls the game's
# StarterMenu_Scene makes, defined before this repo's plugin file is loaded again over it (at boot it did not exist).
class StarterMenu_Scene
  def initialize
    @options_to_use = [["Kanto", [:BULBASAUR, :CHARMANDER, :SQUIRTLE]], ["Johto", [:CHIKORITA, :CYNDAQUIL, :TOTODILE]]]
  end

  def pbStartScene
    @index = 0
    cursor_max_opcion
    pbRedrawList
  end

  def cursor_max_opcion
    @tam_menu = @options_to_use.length
    pbDrawTextPositions(nil, [["Elige tus Iniciales", 256, 26]])
    :title_drawn
  end

  # The selection loop, reduced to the moves it makes: each one redraws the list.
  def pbSelectElement(moves)
    moves.each do |i|
      @index = i
      pbRedrawList
    end
    @index
  end

  def pbRedrawList; :list_drawn; end
end

load File.expand_path("../../../plugins/misc_scripts_anil.rb", File.dirname(__FILE__))

Suite.define("anil starters: the menu's painted title comes first, then the focused region queued") do
  st = PokeAccess::StartersV21
  scene = StarterMenu_Scene.new
  eq "the title's paint keeps its own return", scene.cursor_max_opcion, :title_drawn
  SpeakCapture.clear
  eq "the build keeps its own return", scene.pbStartScene, :list_drawn
  kanto = st.text(scene)
  truthy "the focused region reads (#{kanto})", !kanto.to_s.empty?
  eq "the build's redraw says the region, which the caller's message then cuts", SpeakCapture.log, [[kanto, true]]
  SpeakCapture.clear
  eq "the selection keeps its own return", scene.pbSelectElement([1]), 1
  eq "as the selection opens, the title interrupting and the region queued after it; a move then interrupts",
     SpeakCapture.log, [["Elige tus Iniciales", true], [kanto, false], [st.text(scene), true]]
end
