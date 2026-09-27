# The v22 bag (UI::BagVisuals): its item list is inactive, so it is read only by two hooks that must not repeat each
# other, refresh_on_index_changed (items) and set_pocket (pockets). Gamedata pass.

# A two-pocket bag: a stackable item, a machine (display_name differs from name) and an important item
# (show_quantity? false), plus a second pocket with two entries so a move inside it is testable.
def bag_v22_bag
  TestBag.new({ :Items    => [[:POTION, 3], [:TM01, 1], [:KEYCARD, 1]],
                :Medicine => [[:ELIXIR, 7], [:REVIVE, 2]] }, :Items)
end

Suite.define("v22 bag: the focused item is read once, with its quantity") do
  vis = UI::BagVisuals.new(bag_v22_bag)

  vis.set_index(0)
  potion = PokeAccess::I18n.t(:bag_item, :name => "ItemPOTION", :qty => 3)
  spoke_once "the focused item is read with its name and quantity", /#{Regexp.escape(potion)}/

  SpeakCapture.clear
  vis.refresh_on_index_changed(0)
  silent "a redraw on the same entry says nothing"

  SpeakCapture.clear
  vis.set_index(1)
  spoke_once "moving to another entry reads it", /ItemTM01/
  not_spoke "and does not repeat the entry left behind", /ItemPOTION/
end

# The dedup lives on the screen instance, so a reopened bag reads the entry under the cursor again.
Suite.define("v22 bag: reopening the bag re-reads the entry the cursor is on") do
  bag = bag_v22_bag
  first = UI::BagVisuals.new(bag)
  first.set_index(0)
  spoke_once "the open reads the focused item", /ItemPOTION/

  SpeakCapture.clear
  first.set_index(0)
  silent "the same screen on the same entry stays silent"

  SpeakCapture.clear
  UI::BagVisuals.new(bag).set_index(0)
  spoke_once "a reopened bag reads the same entry again", /ItemPOTION/
end

# A machine reads its move, an important item no quantity, and the row past the last item is the close-bag label.
Suite.define("v22 bag: machine, important item and the close row each read their own way") do
  vis = UI::BagVisuals.new(bag_v22_bag)

  vis.set_index(1)
  spoke_once "a machine is read with the move it teaches (display_name, not the bare id)",
             /ItemTM01 MoveTHUNDERBOLT/

  SpeakCapture.clear
  vis.set_index(2)
  eq "an important item is read by name alone, with no quantity", SpeakCapture.lines, ["ItemKEYCARD"]

  SpeakCapture.clear
  vis.set_index(3)
  eq "the row past the last item is the close-bag label", SpeakCapture.lines,
     [PokeAccess::I18n.t(:mn_close_bag)]
end

# set_pocket says the pocket and its item in one line and primes the nav dedup, so the refresh_on_index_changed
# navigate calls on the same frame stays silent; a real move after it still reads.
Suite.define("v22 bag: a pocket change reads pocket plus item once and primes the nav dedup") do
  vis = UI::BagVisuals.new(bag_v22_bag)
  vis.set_index(2)
  SpeakCapture.clear

  vis.set_pocket(:Medicine)
  pocket = PokeAccess::I18n.t(:bag_pocket, :name => "Medicine")
  elixir = PokeAccess::I18n.t(:bag_item, :name => "ItemELIXIR", :qty => 7)
  eq "the pocket change speaks exactly one line", SpeakCapture.lines.length, 1
  spoke "the new pocket is named", /#{Regexp.escape(pocket)}/
  spoke "and its focused item is read in the same line", /#{Regexp.escape(elixir)}/
  not_spoke "the item of the pocket left behind is not read", /ItemKEYCARD/

  SpeakCapture.clear
  vis.refresh_on_index_changed(2)
  silent "the cursor callback navigate fires right after does not repeat the item"

  SpeakCapture.clear
  vis.set_index(1)
  spoke_once "a real move inside the new pocket is still read", /ItemREVIVE/
end
