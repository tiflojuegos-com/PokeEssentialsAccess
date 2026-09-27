# Anil's monotype type picker: its entries are display rows ([name, symbol, starters]), not type ids. The runner loads
# another profile, so the spec requires this one's file itself, after the scene below exists for its hooks to bind:
# MonotypeMenu::MonotypeMenu_Scene reduced to the calls the game's makes, its title and list painted by private methods.
module MonotypeMenu
  class MonotypeMenu_Scene
    def initialize(type_list, primary_list)
      @type_list = type_list
      @primary_list = primary_list
    end

    def pbStartScene
      @index = 0
      configure_menu
      pbRedrawList
      :started
    end

    # The selection loop, reduced to the moves it makes: each one redraws the list.
    def pbSelectElement(moves)
      moves.each do |i|
        @index = i
        pbRedrawList
      end
      @index
    end

    private

    def configure_menu
      @menu_size = @type_list.length + 1
      create_overlay_title
    end

    def create_overlay_title
      pbDrawTextPositions(nil, [["Elige un tipo Monotype", 256, 26]])
      :title_drawn
    end

    def pbRedrawList; :list_drawn; end
  end
end

require File.expand_path("../../../games/anil/monotype", File.dirname(__FILE__))

# A row speaks its display name, and the option past the rows is the other list or the way back.
Suite.define("anil monotype: rows are [name, symbol, starters], and the last option is two actions") do
  mono = PokeAccess::AnilMonotype
  rows = [["Planta", :GRASS, [:SNOVER]], ["Fuego", :FIRE, [:MAGBY]]]

  eq "a row speaks its own display name, not the array's inspect", mono.type_name(rows[0]), "Planta"

  scene = Object.new
  scene.instance_variable_set(:@type_list, rows)
  scene.instance_variable_set(:@primary_list, true)
  scene.instance_variable_set(:@index, 1)
  eq "the focused row", mono.text(scene), PokeAccess::I18n.t(:mono_type, :type => "Fuego")

  scene.instance_variable_set(:@index, rows.length)
  eq "from the recommended list it offers the other one", mono.text(scene), PokeAccess::I18n.t(:mono_other)
  scene.instance_variable_set(:@primary_list, false)
  eq "from the other list it goes back", mono.text(scene), PokeAccess::I18n.t(:mono_back)
end

# The list paints its title once as it opens ("Elige un tipo Monotype"), before its first row; each move redraws it.
Suite.define("anil monotype: the list's painted title comes first, and its first row is queued after it") do
  t = PokeAccess::I18n
  scene = MonotypeMenu::MonotypeMenu_Scene.new([["Planta", :GRASS, [:SNOVER]], ["Fuego", :FIRE, [:MAGBY]]], true)
  SpeakCapture.clear
  eq "the opening keeps its own return", scene.pbStartScene, :started
  eq "the title interrupting, then the first row queued after it", SpeakCapture.log,
     [["Elige un tipo Monotype", true], [t.t(:mono_type, :type => "Planta"), false]]
  SpeakCapture.clear
  eq "the selection keeps its own return", scene.pbSelectElement([1]), 1
  eq "a later move interrupts", SpeakCapture.log, [[t.t(:mono_type, :type => "Fuego"), true]]
  SpeakCapture.clear
  scene.pbSelectElement([1])
  silent "a redraw that changed nothing stays quiet"
  SpeakCapture.clear
  scene.pbSelectElement([2])
  eq "and the trailing option, from the recommended list, offers the other one", SpeakCapture.lines,
     [t.t(:mono_other)]
  eq "the title's paint keeps its own return", scene.send(:create_overlay_title), :title_drawn
end
