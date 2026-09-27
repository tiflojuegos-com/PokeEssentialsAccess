# The v22 PC screen (UI::PokemonStorageVisuals): cursor index -1 is the box name, -2 the party button, -3 close,
# and 0 and up a slot, read with its row and column.

# Two boxes and a party column; the first box's slot 1 is empty and slot 2 fainted.
def storage_v22_pc
  alpha = TestBox.new("Alpha", [Poke.build(:name => "Bulba", :level => 12),
                                nil,
                                Poke.build(:name => "Fainty", :level => 9, :hp => 0)])
  beta  = TestBox.new("Beta", [Poke.build(:name => "Char", :level => 25)])
  TestStorage.new([alpha, beta], [Poke.build(:name => "Squir", :level => 30)])
end

# The row/column tail the box grid appends to every slot line.
def storage_v22_pos(row, col)
  PokeAccess::I18n.t(:pc_pos, :row => row, :col => col)
end

# The rest of a stored stub Pokemon's panel line: its ability and no item.
def storage_v22_panel
  [PokeAccess::I18n.t(:pc_ability, :a => "Ability1"), PokeAccess::I18n.t(:pc_no_item)].join(", ")
end

Suite.define("v22 storage: the focused slot is read with position, emptiness and the fainted flag") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)
  eq "opening the PC reads the slot under the cursor, with its row and column and the panel, as the gen-6 PC",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Bulba \xE2\x99\x82", :level => 12) + storage_v22_pos(1, 1) + ", " +
      storage_v22_panel]

  SpeakCapture.clear
  vis.set_index(0)
  silent "re-asserting the same slot says nothing"

  SpeakCapture.clear
  vis.set_index(1)
  eq "an empty slot is announced as empty, keeping its position",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_empty) + storage_v22_pos(1, 2)]

  SpeakCapture.clear
  vis.set_index(2)
  eq "a fainted Pokemon is flagged (the healthy one above carried no such suffix)",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Fainty \xE2\x99\x82", :level => 9) + ", " +
      PokeAccess::I18n.t(:pk_fainted) + storage_v22_pos(1, 3) + ", " + storage_v22_panel]

  PokeAccess::Config.verbosity = :brief
  SpeakCapture.clear
  vis.set_index(0)
  eq "in brief the slot says the name and level alone",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_slot, :name => "Bulba", :level => 12)]
  eq "and Ctrl+T says the slot whole", PokeAccess::Info.row_text,
     PokeAccess::I18n.t(:pc_slot, :name => "Bulba \xE2\x99\x82", :level => 12) + storage_v22_pos(1, 1) + ", " + storage_v22_panel
end

# The dedup is per screen instance, so a reopened PC reads the same slot again.
Suite.define("v22 storage: reopening the PC re-reads the slot the cursor is on") do
  pc = storage_v22_pc
  vis = UI::PokemonStorageVisuals.new(pc)
  SpeakCapture.clear
  vis.set_index(0)
  silent "the same screen on the same slot stays silent"

  SpeakCapture.clear
  UI::PokemonStorageVisuals.new(pc)
  spoke_once "a reopened PC reads that slot again", /Bulba/
end

# The negative indices are controls; -2 is Team inside a box and Back once the party panel is up.
Suite.define("v22 storage: the box row and the control buttons name themselves") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)

  SpeakCapture.clear
  vis.set_index(-1)
  eq "the box row reads the box name and the keys that turn it", SpeakCapture.lines,
     [[PokeAccess::I18n.t(:pc_box, :name => "Alpha"), PokeAccess::I18n.t(:pc_box_hint)].join(". ")]

  SpeakCapture.clear
  vis.set_index(-3)
  eq "the close control reads the close label", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_close)]

  SpeakCapture.clear
  vis.set_index(-2)
  eq "inside a box the party button reads Team", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_team)]
end

# Cycling boxes leaves the cursor index on the box row: only the box name tells the two apart in the dedup key.
Suite.define("v22 storage: cycling boxes is announced even though the cursor index never moves") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)
  vis.set_index(-1)

  SpeakCapture.clear
  vis.go_to_next_box
  eq "the next box is named, once", SpeakCapture.lines,
     [[PokeAccess::I18n.t(:pc_box, :name => "Beta"), PokeAccess::I18n.t(:pc_box_hint)].join(". ")]

  SpeakCapture.clear
  vis.set_index(-1)
  silent "re-asserting the box row after the change stays quiet"

  SpeakCapture.clear
  vis.go_to_previous_box
  eq "cycling back names the first box again", SpeakCapture.lines,
     [[PokeAccess::I18n.t(:pc_box, :name => "Alpha"), PokeAccess::I18n.t(:pc_box_hint)].join(". ")]
end

# The party column's slots have no row or column and its -2 button is Back, through the same set_index hook.
Suite.define("v22 storage: the party panel reads party members and its own Back button") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)

  SpeakCapture.clear
  vis.show_party_panel
  eq "opening the party panel reads the first party member, with no row/column tail",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Squir \xE2\x99\x82", :level => 30) + ", " + storage_v22_panel]

  SpeakCapture.clear
  vis.set_index(-2)
  eq "in the party panel the same button reads Back, not Team",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_back)]

  SpeakCapture.clear
  vis.hide_party_panel
  eq "back inside the box that button reads Team again",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_team)]
end

# While the cursor carries a Pokemon, every slot reads as a swap with it or a place to drop it.
Suite.define("v22 storage: a held Pokemon turns every slot into a swap or a placement") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)
  vis.hold_pokemon(Poke.build(:name => "Pika", :level => 15))

  SpeakCapture.clear
  vis.set_index(0)
  eq "over an occupied slot it reads as a swap with the held Pokemon", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_swap, :name => "Bulba", :held => "Pika") + storage_v22_pos(1, 1)]

  SpeakCapture.clear
  vis.set_index(1)
  eq "over an empty slot it reads as a placement", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_place, :held => "Pika") + storage_v22_pos(1, 2)]
end
