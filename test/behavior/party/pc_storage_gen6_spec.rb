# The gen-6 cursor readers of core/party/party_storage.rb: the game re-asserts the focused slot every frame, so each
# slot is read once, and again when its box, the held Pokemon or the column changes, or the PC reopens.

# The trailing button sprites, as both engine eras name them: the class is all that tells which button a slot holds.
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

# The rest of a stub Pokemon's box panel line: the first ability (Poke.build's) and no item.
def pc_panel_rest
  ", " + PokeAccess::I18n.t(:pc_ability, :a => PokeAccess::Data.ability_name(1)) + ", " + PokeAccess::I18n.t(:pc_no_item)
end

# The storage screen, whose only job here is holding the Pokemon the player picked up.
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
  eq "the box it opens on, then the focused slot: its name and the sex sign beside it, level and grid position",
     SpeakCapture.lines,
     ["Caja 1. " + PokeAccess::I18n.t(:pc_slot, :name => "Bulba \xE2\x99\x82", :level => 5) +
      PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 1) + pc_panel_rest]
  eq "a cursor move interrupts whatever was being said", SpeakCapture.log[0][1], true

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 0, nil)
  PokeAccess::Party.announce_pc(scene, 0, nil)
  silent "the screen re-asserting the same slot every frame says nothing"

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 7, nil)
  eq "moving to slot 7 reads it, on row 2 column 2",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Char \xE2\x99\x82", :level => 9) +
      PokeAccess::I18n.t(:pc_pos, :row => 2, :col => 2) + pc_panel_rest]

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
  eq "picking a Pokemon up re-reads the same slot as a swap, the one in hand with the sign its panel shows",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_swap, :name => "Pidgey", :held => "Squirt \xE2\x99\x82") +
      PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 1)]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 5, nil)
  eq "an empty slot with something in hand offers to place it there",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_place, :held => "Squirt \xE2\x99\x82") +
      PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 6)]

  egg = Poke.build(:name => "Huevo", :gender => 1)
  def egg.egg?; true; end
  screen.hold(egg)
  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 5, nil)
  eq "an egg in hand has no sign, as its panel draws none", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_place, :held => "Huevo") + PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 6)]
  screen.hold(squirt)

  SpeakCapture.clear
  screen.hold(nil)
  PokeAccess::Party.announce_pc(scene, 0, [bulba])
  eq "crossing into the party column re-reads index 0 there, with no grid position",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_slot, :name => "Bulba \xE2\x99\x82", :level => 5) + pc_panel_rest]
end

Suite.define("pc storage gen-6: each control button has its own line") do
  storage = pc_storage(["Caja 1"], {})
  scene = World.stub_scene(:@screen => pc_screen, :@storage => storage)
  box = [PokeAccess::I18n.t(:pc_box, :name => "Caja 1"), PokeAccess::I18n.t(:pc_box_hint)].join(". ")
  want = { -1 => box, -2 => PokeAccess::I18n.t(:pc_team),
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

# The party screen's own reader: pbChangeSelection hands it the new index and the old one, which is its dedup; the
# line carries sex, level, HP and the fainted flag.
Suite.define("party gen-6: the slot is read on a move, and a fainted one says so") do
  healthy = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => 0)
  ko = Poke.build(:name => "Char", :level => 9, :hp => 0, :totalhp => 24, :gender => 1)
  party = [healthy, ko]
  scene = Object.new
  scene.instance_variable_set(:@sprites, { "pokemon2" => PokeSelectionCancelSprite.new })

  PokeAccess::Party.announce_party(scene, party, 0, -1)
  eq "moving onto a slot reads name, sex, level and hp",
     SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Bulba", :sex => " \xE2\x99\x82",
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
     [PokeAccess::I18n.t(:pty_member, :name => "Char", :sex => " \xE2\x99\x80",
                         :level => 9, :hp => 0, :tot => 24) + ", " + PokeAccess::I18n.t(:pk_fainted)]

  SpeakCapture.clear
  PokeAccess::Party.announce_party(scene, party, 2, 1)
  eq "the button past the last Pokemon is the cancel label",
     SpeakCapture.lines, [PokeAccess::I18n.t(:pc_cancel)]

  SpeakCapture.clear
  PokeAccess::Party.announce_party(scene, party, 0, 2)
  spoke_once "and coming back up re-reads the first slot", /Bulba/
end

# Multiselect puts Confirm at slot 6 and Cancel at 7, told apart by the sprite's class.
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

# What the box panel shows, and only that: no sign for a genderless Pokemon, the shiny star, an egg as nothing but
# an egg, and the Back button past the party column's last slot.
Suite.define("pc storage gen-6: the slot says what its panel shows, and the party column ends in Back") do
  magnet = Poke.build(:name => "Magnet", :level => 20, :gender => 2)
  star = Poke.build(:name => "Brillo", :level => 11, :gender => 1, :shiny => true)
  egg = Poke.build(:name => "Huevo", :level => 1, :gender => 0)
  def egg.egg?; true; end
  storage = pc_storage(["Caja 1"], { [0, 0] => magnet, [0, 1] => star, [0, 2] => egg })
  scene = World.stub_scene(:@screen => pc_screen, :@storage => storage)
  t = PokeAccess::I18n

  PokeAccess::Party.announce_pc(scene, 0, nil)
  eq "a genderless Pokemon has no sign to say", SpeakCapture.lines,
     ["Caja 1. " + t.t(:pc_slot, :name => "Magnet", :level => 20) + t.t(:pc_pos, :row => 1, :col => 1) + pc_panel_rest]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 1, nil)
  eq "a female one says her sign, and after where it sits, the shiny star beside it", SpeakCapture.lines,
     [t.t(:pc_slot, :name => "Brillo \xE2\x99\x80", :level => 11) + t.t(:pc_pos, :row => 1, :col => 2) +
      ", " + t.t(:pk_shiny) + pc_panel_rest]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 2, nil)
  eq "an egg is only an egg", SpeakCapture.lines, [t.t(:pty_egg) + t.t(:pc_pos, :row => 1, :col => 3)]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 6, [magnet])
  eq "the stop after the six party slots is the Back button", SpeakCapture.lines, [t.t(:pc_back)]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 3, [magnet])
  eq "an empty party slot is still empty", SpeakCapture.lines, [t.t(:pc_empty)]
end

# Teaching a machine or using an item annotates each panel "able" or "not able", said in place of the HP.
Suite.define("party gen-6: a panel's annotation joins its member's line") do
  able = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => 0)
  unable = Poke.build(:name => "Char", :level => 9, :hp => 24, :totalhp => 24, :gender => 1)
  panels = {}
  [["APTO", 0], ["NO APTO", 1]].each do |text, i|
    panel = Object.new
    panel.instance_variable_set(:@text, text)
    panels["pokemon#{i}"] = panel
  end
  scene = World.stub_scene(:@sprites => panels)
  t = PokeAccess::I18n

  PokeAccess::Party.announce_party(scene, [able, unable], 0, -1)
  eq "the able member says so, where the panel hides the HP to write it", SpeakCapture.lines,
     [t.t(:pty_head, :name => "Bulba", :sex => " \xE2\x99\x82", :level => 5) + ", APTO"]

  SpeakCapture.clear
  PokeAccess::Party.announce_party(scene, [able, unable], 1, 0)
  match "and the one that is not, too", SpeakCapture.lines.join(" "), /, NO APTO\z/
end

# The row and column follow the box's own width: PokemonBox::BOX_WIDTH where it exists, six otherwise; a game with
# its own box shape overrides the resolver in its profile.
Suite.define("pc storage: the row and column follow the width the game's own box has") do
  party = PokeAccess::Party
  had = defined?(PokemonBox) ? true : false
  begin
    eq "with no box class to ask, the shared six stands", party.box_columns, 6
    Object.const_set(:PokemonBox, Module.new) unless had
    PokemonBox.const_set(:BOX_WIDTH, 8)
    eq "the game's own width is what a row holds", party.box_columns, 8

    char = Poke.build(:name => "Char", :level => 9)
    storage = pc_storage(["Caja 1"], { [0, 7] => char })
    scene = World.stub_scene(:@screen => pc_screen, :@storage => storage)
    SpeakCapture.clear
    party.announce_pc(scene, 7, nil)
    eq "and slot 7 of an eight-wide box is row 1 column 8, not row 2 column 2",
       SpeakCapture.lines,
       ["Caja 1. " + PokeAccess::I18n.t(:pc_slot, :name => "Char \xE2\x99\x82", :level => 9) +
        PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 8) + pc_panel_rest]
  ensure
    PokemonBox.send(:remove_const, :BOX_WIDTH) if defined?(PokemonBox) && PokemonBox.const_defined?(:BOX_WIDTH)
    Object.send(:remove_const, :PokemonBox) if !had && defined?(PokemonBox)
  end
end

# The party column's Back button sits past the party's capacity: a global max_party_size first, then the setting.
Suite.define("pc storage: the party column's Back button is where the game says the party ends") do
  party = PokeAccess::Party
  eq "with no function of its own, the setting decides", party.party_capacity, 6
  begin
    Object.send(:define_method, :max_party_size) { 4 }
    eq "a game that shrinks the party is asked first", party.party_capacity, 4
    storage = pc_storage(["Caja 1"], {})
    scene = World.stub_scene(:@screen => pc_screen, :@storage => storage)
    SpeakCapture.clear
    party.announce_pc(scene, 4, [Poke.build(:name => "Bulba", :level => 5)])
    eq "so the stop past the last slot is the Back button", SpeakCapture.lines,
       [PokeAccess::I18n.t(:pc_back)]
  ensure
    Object.send(:remove_method, :max_party_size) rescue nil
  end
end

# The gen-6 party screen opens, or starts a forced switch, without moving the cursor: the choice loop's entry says
# the member, queued behind the help line, and hands it to the info key.
Suite.define("party gen-6: the member the cursor rests on is read as the list takes a choice") do
  bulba = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => 0)
  char = Poke.build(:name => "Char", :level => 9, :hp => 0, :totalhp => 24, :gender => 1)
  scene = PokemonScreen_Scene.new([bulba, char])
  SpeakCapture.clear
  scene.pbChoosePokemon
  eq "opening reads the first member", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Bulba", :sex => " \xE2\x99\x82", :level => 5, :hp => 20, :tot => 20)]
  eq "queued behind the help line", SpeakCapture.log.last[1], false
  eq "and the info key has it", PokeAccess::Info.instance_variable_get(:@data), bulba
  SpeakCapture.clear
  scene.pbChoosePokemon(true, 1)
  truthy "a forced switch reads the one it starts on", SpeakCapture.lines.join(" ").include?("Char")
end

# A box turned under a cursor that stays on its slot (the jump keys) is named before the slot.
Suite.define("pc storage: a box turned under the cursor is named before the slot") do
  bulba = Poke.build(:name => "Bulba", :level => 5)
  char = Poke.build(:name => "Char", :level => 9)
  storage = pc_storage(["Caja 1", "Caja 2"], { [0, 3] => bulba, [1, 3] => char })
  scene = World.stub_scene(:@screen => pc_screen, :@storage => storage)
  PokeAccess::Party.announce_pc(scene, 3, nil)
  SpeakCapture.clear
  storage.open_box = 1
  PokeAccess::Party.announce_pc(scene, 3, nil)
  eq "the new box, then the slot in it", SpeakCapture.lines,
     ["Caja 2. " + PokeAccess::I18n.t(:pc_slot, :name => "Char \xE2\x99\x82", :level => 9) +
      PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 4) + pc_panel_rest]

  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 4, nil)
  eq "moving inside the same box says the slot alone", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_empty) + PokeAccess::I18n.t(:pc_pos, :row => 1, :col => 5)]
end

# The box the screen opens on is named with the first slot read; after that only a turned box is, not a return from
# a menu, nor one whose header was already read.
Suite.define("pc storage: the box the screen opens on is named once, with the first slot read") do
  bulba = Poke.build(:name => "Bulba", :level => 5)
  storage = pc_storage(["Caja 7"], { [0, 0] => bulba })
  scene = PokemonStorageScene.new
  scene.instance_variable_set(:@screen, pc_screen)
  scene.instance_variable_set(:@storage, storage)
  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 0, nil)
  match "opening, the box before the slot", SpeakCapture.lines.join(" "), /\ACaja 7\. .*Bulba/
  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 1, nil)
  not_spoke "the next slot in it, the slot alone", /Caja 7/
  PokeAccess.speak("Mover", true)
  scene.pbSelectBoxInternal(nil)
  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 1, nil)
  not_spoke "and back from a menu, still the slot alone", /Caja 7/

  header_first = PokemonStorageScene.new
  header_first.instance_variable_set(:@screen, pc_screen)
  header_first.instance_variable_set(:@storage, storage)
  PokeAccess::Party.announce_pc(header_first, -1, nil)
  SpeakCapture.clear
  PokeAccess::Party.announce_pc(header_first, 0, nil)
  not_spoke "a header already read has named it", /Caja 7/
end

# Back in the party column from a command menu, its loop starts over and says the member under the cursor again;
# not when that member is still the last thing said.
Suite.define("pc storage: coming back to the party column from a menu reads the member again") do
  bulba = Poke.build(:name => "Bulba", :level => 5)
  party = [bulba]
  scene = PokemonStorageScene.new
  scene.instance_variable_set(:@screen, pc_screen)
  scene.instance_variable_set(:@storage, pc_storage(["Caja 1"], {}))
  PokeAccess::Party.announce_pc(scene, 0, party)
  SpeakCapture.clear
  PokeAccess::Party.announce_pc(scene, 0, party)
  silent "the same member again says nothing while the column is open"
  scene.pbSelectPartyInternal(party, false)
  PokeAccess::Party.announce_pc(scene, 0, party)
  silent "nor when its loop starts with the member still the last thing said"
  PokeAccess.speak("Mover", true)
  SpeakCapture.clear
  scene.pbSelectPartyInternal(party, false)
  PokeAccess::Party.announce_pc(scene, 0, party)
  eq "back from the menu it is read once more", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_slot, :name => "Bulba \xE2\x99\x82", :level => 5) + pc_panel_rest]
end

# The box panel paints more than the name and level: the type icons, the ability and the held item it writes
# (or "no item"), and the marks, which the gen-6 games draw as signs, dark when set.
Suite.define("pc storage: the slot says the rest of the panel, marks as the signs it paints") do
  t = PokeAccess::I18n
  had = defined?(PokemonStorage)
  Object.const_set(:PokemonStorage, Class.new) unless had
  PokemonStorage.const_set(:MARKINGCHARS, ["\xE2\x97\x8F", "\xE2\x96\xA0", "\xE2\x96\xB2", "\xE2\x99\xA5"])
  begin
    zap = Poke.build(:name => "Zap", :level => 30, :ability => 9, :item => 25)
    zap.define_singleton_method(:type1) { 13 }
    zap.define_singleton_method(:type2) { 2 }
    zap.define_singleton_method(:markings) { 0b1001 }
    scene = World.stub_scene(:@screen => pc_screen, :@storage => pc_storage(["Caja 1"], { [0, 0] => zap }))
    SpeakCapture.clear
    PokeAccess::Party.announce_pc(scene, 0, nil)
    eq "types, ability, item and the two set marks as painted", SpeakCapture.lines,
       ["Caja 1. " + t.t(:pc_slot, :name => "Zap \xE2\x99\x82", :level => 30) + t.t(:pc_pos, :row => 1, :col => 1) + ", " +
        [t.t(:pc_types, :t => "Tipo13 Tipo2"), t.t(:pc_ability, :a => "Habilidad9"), t.t(:pc_item, :i => "Repel"),
         t.t(:mk_list, :list => "\xE2\x97\x8F, \xE2\x99\xA5")].join(", ")]
  ensure
    PokemonStorage.send(:remove_const, :MARKINGCHARS)
    Object.send(:remove_const, :PokemonStorage) unless had
  end
end

# The party panel's icons: one state slot (fainted before an ailment; pokerus when empty, v17 and later only), the
# held item and the Exp. Share mark.
Suite.define("party: the line says the state slot, the item icon and the Exp. Share mark the panel draws") do
  t = PokeAccess::I18n
  sleepy = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :status => 1, :item => 25)
  sleepy.define_singleton_method(:expshare) { true }
  sleepy.define_singleton_method(:pokerusStage) { 1 }
  line = PokeAccess::Party.party_line([sleepy], 0)
  eq "status, item and Exp. Share, and no pokerus on a panel without its icon", line,
     t.t(:pty_member, :name => "Bulba", :sex => " \xE2\x99\x82", :level => 5, :hp => 20, :tot => 20) + ", " +
     [t.t(:st_sleep), t.t(:pty_item), t.t(:pty_expshare)].join(", ")

  healthy = Poke.build(:name => "Char", :level => 9, :hp => 24, :totalhp => 24)
  healthy.define_singleton_method(:pokerusStage) { 1 }
  eq "the v17-and-later panel shows pokerus when nothing else fills the slot",
     PokeAccess::Party.member_line(healthy, :pokerus_slot => true),
     t.t(:pty_member, :name => "Char", :sex => " \xE2\x99\x82", :level => 9, :hp => 24, :tot => 24) + ", " +
     t.t(:pk_pokerus)
  fainted = Poke.build(:name => "Dead", :level => 9, :hp => 0, :totalhp => 24, :status => 1)
  match "fainted comes before any ailment in the one slot",
        PokeAccess::Party.member_line(fainted, :pokerus_slot => true), /PS, #{t.t(:pk_fainted)}\z/

  party = PokeAccess::Party
  scene = PokemonScreen_Scene.new rescue Object.new
  falsy "a gen-6 party slot leaves pokerus out on a v16 panel",
        party.member_text(scene, [healthy], 0).include?(t.t(:pk_pokerus))
  truthy "a member is the info key's Pokemon and its row", PokeAccess::Info.row_text.to_s.include?("Char")
  eq "the button past the party takes its place, for T and Ctrl+T alike",
     [party.member_text(scene, [healthy], 1), PokeAccess::Info.row_text, PokeAccess::Info.info_text],
     [t.t(:pc_cancel), t.t(:pc_cancel), t.t(:pc_cancel)]
  class << party
    alias_method :spec_panel_pokerus?, :panel_pokerus?
    def panel_pokerus?; true; end
  end
  begin
    truthy "and says it where the profile's panel draws it (Awakening's v17 one)",
           party.member_text(scene, [healthy], 0).include?(t.t(:pk_pokerus))
  ensure
    class << party
      alias_method :panel_pokerus?, :spec_panel_pokerus?
      remove_method :spec_panel_pokerus?
    end
  end
end
