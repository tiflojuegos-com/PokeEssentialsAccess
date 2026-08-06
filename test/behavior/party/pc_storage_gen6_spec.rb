# The two gen-6 cursor readers in core/party/party_storage.rb, both of which had no assertions at all.
# They are the "speak the focused entry" shape, and the shape is where the bugs live: the game re-asserts
# the focused slot on every frame (pbUpdateOverlay runs continuously, pbChangeSelection is called with the
# same index), so a reader that speaks unconditionally repeats the same Pokemon forever, while one that
# dedups on the index alone goes MUTE on everything that changes without the index changing -- flipping to
# another box, picking a Pokemon up, or crossing from the box grid to the party column, all of which leave
# the cursor number exactly where it was. announce_pc's dedup key is the tuple that covers those, and it
# lives on the SCENE, so reopening the PC reads the slot the cursor sits on instead of staying silent.

# The trailing button sprites, named as both engine eras name them: the concrete class is the only place the
# screen records which button a slot holds, since the label is drawn into a bitmap and thrown away.
class PokeSelectionCancelSprite; end
class PokeSelectionCancelSprite2; end
class PokeSelectionConfirmSprite; end

# A PC storage shaped as the gen-6 PokemonStorage the reader reads: storage[box] is the box (it has a name),
# storage[box, index] the Pokemon in a slot, currentBox the open box.
def pc_storage(box_names, mons)
  s = Object.new
  s.instance_variable_set(:@names, box_names)
  s.instance_variable_set(:@mons, mons)
  s.instance_variable_set(:@cur, 0)
  s.define_singleton_method(:currentBox) { @cur }
  s.define_singleton_method(:open_box=) { |b| @cur = b }
  s.define_singleton_method(:[]) do |box, index = nil|
    if index.nil?
      n = @names[box]
      b = Object.new
      b.define_singleton_method(:name) { n }
      b
    else
      @mons[[box, index]]
    end
  end
  s
end

# The storage SCREEN, whose only job here is holding the Pokemon the player picked up.
def pc_screen
  s = Object.new
  s.define_singleton_method(:pbHeldPokemon) { @held }
  s.define_singleton_method(:hold) { |pk| @held = pk }
  s
end

Suite.define("pc storage gen-6: the cursor reads a slot once and stays quiet until it moves") do
  bulba = Poke.build(:name => "Bulba", :level => 5)
  char = Poke.build(:name => "Char", :level => 9)
  storage = pc_storage(["Caja 1", "Caja 2"], { [0, 0] => bulba, [0, 7] => char })
  scene = World.stub_scene(:@screen => pc_screen, :@storage => storage)

  PokeAccess::Party.announce_pc(scene, 0, nil)
  eq "the focused slot is read with its name, level and grid position",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Bulba", :level => 5) +
      PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 1)]
  eq "a cursor move interrupts whatever was being said", SpeakCapture.log[0][1], true

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 0, nil)
  PokeAccess::Party.announce_pc(scene, 0, nil)
  silent "the screen re-asserting the same slot every frame says nothing"

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 7, nil)
  eq "moving to slot 7 reads it, on row 2 column 2",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Char", :level => 9) +
      PokeAccess::I18n.t(:pc_pos, :row => 2, :col => 2)]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 8, nil)
  eq "an empty slot is announced as empty, with its position",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_empty) + PokeAccess::I18n.t(:pc_pos, :row => 2, :col => 3)]

  SpeakCapture.clear
  scene2 = World.stub_scene(:@screen => pc_screen, :@storage => storage)
  PokeAccess::Party.announce_pc(scene2, 8, nil)
  spoke_once "reopening the PC re-reads the slot the cursor already sits on",
             /#{Regexp.escape(PokeAccess::I18n.t(:pc_empty))}/
end

Suite.define("pc storage gen-6: box, held Pokemon and the party column all re-read the same index") do
  bulba = Poke.build(:name => "Bulba", :level => 5)
  squirt = Poke.build(:name => "Squirt", :level => 7)
  pidgey = Poke.build(:name => "Pidgey", :level => 3)
  storage = pc_storage(["Caja 1", "Caja 2"], { [0, 0] => bulba, [1, 0] => pidgey })
  screen = pc_screen
  scene = World.stub_scene(:@screen => screen, :@storage => storage)

  PokeAccess::Party.announce_pc(scene, 0, nil)
  spoke_once "slot 0 of box 1 is read", /Bulba/

  SpeakCapture.clear
  storage.open_box = 1
  PokeAccess::Party.announce_pc(scene, 0, nil)
  spoke_once "flipping to the next box re-reads slot 0, which is a different Pokemon", /Pidgey/
  not_spoke "and does not repeat the one from the old box", /Bulba/

  SpeakCapture.clear
  screen.hold(squirt)
  PokeAccess::Party.announce_pc(scene, 0, nil)
  eq "picking a Pokemon up re-reads the same slot as a swap",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_swap, :name => "Pidgey", :held => "Squirt") +
      PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 1)]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 5, nil)
  eq "an empty slot with something in hand offers to place it there",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_place, :held => "Squirt") +
      PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 6)]

  SpeakCapture.clear
  screen.hold(nil)
  PokeAccess::Party.announce_pc(scene, 0, [bulba])
  eq "crossing into the party column re-reads index 0 there, with no grid position",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_slot, :name => "Bulba", :level => 5)]
end

Suite.define("pc storage gen-6: each control button has its own line") do
  storage = pc_storage(["Caja 1"], {})
  scene = World.stub_scene(:@screen => pc_screen, :@storage => storage)
  want = { -1 => PokeAccess::I18n.t(:pc_box, :name => "Caja 1"), -2 => PokeAccess::I18n.t(:pc_team),
           -3 => PokeAccess::I18n.t(:pc_close), -4 => PokeAccess::I18n.t(:pc_prev),
           -5 => PokeAccess::I18n.t(:pc_next) }
  got = {}
  want.keys.sort.each do |sel|
    SpeakCapture.clear
    PokeAccess::Party.announce_pc(scene, sel, nil)
    got[sel] = SpeakCapture.lines
  end
  eq "the five controls read their own labels", got, want.keys.inject({}) { |h, k| h[k] = [want[k]]; h }

  PokeAccess::Party.announce_pc(scene, -3, nil)
  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, -3, nil)
  silent "and holding on one of them does not repeat it"
end

# The party screen's own reader: pbChangeSelection hands it the new index AND the old one, so "the cursor
# did not move" is the reader's dedup. Its line is the one the player navigates the party by, so the fields
# it carries (sex, level, current/total hp, and the fainted flag) are pinned here too -- a fainted Pokemon
# that reads like a healthy one is the difference between switching it in and losing the fight.
Suite.define("party gen-6: the slot is read on a move, and a fainted one says so") do
  healthy = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => 0)
  ko = Poke.build(:name => "Char", :level => 9, :hp => 0, :totalhp => 24, :gender => 1)
  party = [healthy, ko]
  scene = Object.new
  scene.instance_variable_set(:@sprites, { "pokemon2" => PokeSelectionCancelSprite.new })

  PokeAccess::Party.announce_party(scene, party, 0, -1)
  eq "moving onto a slot reads name, sex, level and hp",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Bulba", :sex => " " + PokeAccess::I18n.t(:pk_male),
                         :level => 5, :hp => 20, :tot => 20)]
  not_spoke "a healthy Pokemon is not called fainted",
            /#{Regexp.escape(PokeAccess::I18n.t(:pk_fainted))}/

  SpeakCapture.clear
  PokeAccess::Party.announce_party(scene, party, 0, 0)
  silent "the same index twice is not a move, so nothing is said"

  SpeakCapture.clear
  PokeAccess::Party.announce_party(scene, party, 1, 0)
  eq "the next slot is read, and a fainted Pokemon says so",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Char", :sex => " " + PokeAccess::I18n.t(:pk_female),
                         :level => 9, :hp => 0, :tot => 24) + ", " + PokeAccess::I18n.t(:pk_fainted)]

  SpeakCapture.clear
  PokeAccess::Party.announce_party(scene, party, 2, 1)
  eq "the button past the last Pokemon is the cancel label",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_cancel)]

  SpeakCapture.clear
  PokeAccess::Party.announce_party(scene, party, 0, 2)
  spoke_once "and coming back up re-reads the first slot", /Bulba/
end

# With multiselect the screen swaps the single CANCEL for a CONFIRM at slot 6 and a CANCEL at 7, and both
# were read as "cancel": on the Battle Challenge entry screen the button that commits the team and the one
# that throws it away were indistinguishable. Which button it is comes from the sprite, whose concrete class
# is named for what it does in both engine eras.
Suite.define("party: the multiselect buttons are told apart, not both called cancel") do
  party = [Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => 0)]
  scene = Object.new
  scene.instance_variable_set(:@sprites, { "pokemon6" => PokeSelectionConfirmSprite.new,
                                           "pokemon7" => PokeSelectionCancelSprite2.new })
  eq "slot 6 is the confirm button", PokeAccess::Party.party_button(scene, 6), PokeAccess::I18n.t(:pc_confirm)
  eq "slot 7 is the cancel button", PokeAccess::Party.party_button(scene, 7), PokeAccess::I18n.t(:pc_cancel)

  PokeAccess::Party.announce_party(scene, party, 6, 5)
  eq "and moving onto it says so", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_confirm)]
end
