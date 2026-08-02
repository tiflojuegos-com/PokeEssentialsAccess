# Anil's monotype type picker. Two independent faults made the whole screen useless and neither showed up
# anywhere: the hook named the class without its enclosing module (an absent class is normal variance, so
# it is silent BY DESIGN and never lands in Hooks.missing), and the entries are display rows, not type ids.
# The runner loads one profile and it is not this one, so the spec pulls the module in itself.
require File.expand_path("../../../games/anil/monotype", File.dirname(__FILE__))

Suite.define("anil monotype: rows are [name, symbol, starters], and the last option is two actions") do
  mono = PokeAccess::AnilMonotype
  rows = [["Planta", :GRASS, [:SNOVER]], ["Fuego", :FIRE, [:MAGBY]]]

  eq "a row speaks its own display name, not the array's inspect", mono.type_name(rows[0]), "Planta"

  scene = Object.new
  scene.instance_variable_set(:@type_list, rows)
  scene.instance_variable_set(:@primary_list, true)
  scene.instance_variable_set(:@index, 1)
  eq "the focused row", mono.text(scene), PokeAccess::I18n.t(:mono_type, :type => "Fuego")

  # The trailing entry sits one past the list and the plugin labels it by which list is showing.
  scene.instance_variable_set(:@index, rows.length)
  eq "from the recommended list it offers the other one", mono.text(scene), PokeAccess::I18n.t(:mono_other)
  scene.instance_variable_set(:@primary_list, false)
  eq "from the other list it goes back", mono.text(scene), PokeAccess::I18n.t(:mono_back)

  SpeakCapture.clear
  scene.instance_variable_set(:@index, 0)
  mono.read(scene)
  spoke "a cursor move speaks", /Planta/
  SpeakCapture.clear
  mono.read(scene)
  silent "a redraw that changed nothing stays quiet"
end
