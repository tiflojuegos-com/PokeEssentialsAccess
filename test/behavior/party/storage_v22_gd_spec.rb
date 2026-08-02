# The v22 PC / storage screen (Essentials v22 UI::PokemonStorageVisuals). Blind play depends entirely on
# what this screen says: the grid is a 6-wide box the cursor walks with no visual feedback, and the same
# cursor index means different things depending on where you are (-1 box name, -2 party button, -3 close,
# 0+ a slot), so a line that drops the row/column, forgets the fainted flag or names the wrong control
# leaves the player moving Pokemon blind. None of it was pinned. Runs only in the gamedata pass.

# Two boxes plus a party column. Slot 1 of the first box is deliberately empty and slot 2 fainted, so the
# empty/fainted branches have a healthy neighbour to contrast against.
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

Suite.define("v22 storage: the focused slot is read with position, emptiness and the fainted flag") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)
  eq "opening the PC reads the slot under the cursor, with its row and column",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Bulba", :level => 12) + storage_v22_pos(1, 1)]

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
     [PokeAccess::I18n.t(:pc_slot, :name => "Fainty", :level => 9) + ", " +
      PokeAccess::I18n.t(:pk_fainted) + storage_v22_pos(1, 3)]
end

# The dedup hangs on the screen instance, so closing and reopening the PC on the same slot must read it
# again -- otherwise the player reopens the box and hears nothing at all.
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

# The three negative indices are controls, not slots, and -2 is the one that changes meaning with the
# panel you are on: Team while you stand in a box, Back once the party panel is up. Reading the wrong one
# sends the player into the party column believing they are leaving the PC.
Suite.define("v22 storage: the box row and the control buttons name themselves") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)

  SpeakCapture.clear
  vis.set_index(-1)
  eq "the box row reads the box name", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_box, :name => "Alpha")]

  SpeakCapture.clear
  vis.set_index(-3)
  eq "the close control reads the close label", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_close)]

  SpeakCapture.clear
  vis.set_index(-2)
  eq "inside a box the party button reads Team", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_team)]
end

# Cycling boxes never touches the index (the cursor stays on the box row), so the dedup key's index half
# does not move: only the box NAME tells the two apart. This is the case a naive index-only dedup swallows,
# leaving left/right on the box row completely mute.
Suite.define("v22 storage: cycling boxes is announced even though the cursor index never moves") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)
  vis.set_index(-1)

  SpeakCapture.clear
  vis.go_to_next_box
  eq "the next box is named", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_box, :name => "Beta")]

  SpeakCapture.clear
  vis.set_index(-1)
  silent "re-asserting the box row after the change stays quiet"

  SpeakCapture.clear
  vis.go_to_previous_box
  eq "cycling back names the first box again", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_box, :name => "Alpha")]
end

# The party column is not a box: its slots have no row/column (there is one column) and its -2 button is
# Back, not Team. Both panels drive the SAME set_index hook, so this is where a line built for the grid
# leaks into the party panel.
Suite.define("v22 storage: the party panel reads party members and its own Back button") do
  vis = UI::PokemonStorageVisuals.new(storage_v22_pc)

  SpeakCapture.clear
  vis.show_party_panel
  eq "opening the party panel reads the first party member, with no row/column tail",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_slot, :name => "Squir", :level => 30)]

  SpeakCapture.clear
  vis.set_index(-2)
  eq "in the party panel the same button reads Back, not Team",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_back)]

  SpeakCapture.clear
  vis.hide_party_panel
  eq "back inside the box that button reads Team again",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_team)]
end

# While the cursor carries a Pokemon every slot means "swap with this" or "drop it here". Without that the
# player hears the slot's own contents and has no way to know they are still holding something.
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
