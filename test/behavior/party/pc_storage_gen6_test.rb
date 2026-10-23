# The gen-6 PC box and party screen readers (core/party/party_storage.rb) through their hooks (party/gen6/party_g6.rb):
# what each slot, member and button says, once per move, and what the info key keeps for it.

# The trailing button sprites of the gen-6 party screen, as both engine eras name them: the class is all that tells
# which button a slot holds.
class PokeSelectionCancelSprite; end
class PokeSelectionCancelSprite2; end
class PokeSelectionConfirmSprite; end

class PcStorageGen6Test < PokeAccessTest
  T = PokeAccess::I18n
  Party = PokeAccess::Party
  MALE = " \xE2\x99\x82"
  FEMALE = " \xE2\x99\x80"

  # The party button, key hint and exit where Royal's PC overlay paints them, listed out of x order for the reader to
  # sort, among stand-in panel texts left of that row or above it.
  ROYAL_ROW = [["Salir", :positions, 586, 390], ["[W]: Buscar", :positions, 436, 390], ["Pika", :positions, 10, 14],
               ["Static", :positions, 86, 312], ["Nv. 5", :positions, 230, 40], ["Equipo: 3", :positions, 292, 390]]

  # A box of the gen-6 PokemonStorage, which has a name.
  Box = Struct.new(:name)

  # A gen-6 PokemonStorage as the reader asks it: storage[box] is a box, storage[box, index] a slot's Pokemon, and
  # currentBox the box open.
  Storage = Struct.new(:names, :mons, :currentBox) do
    def [](box, index = nil)
      index.nil? ? Box.new(names[box]) : mons[[box, index]]
    end
  end

  # The storage screen, which holds the Pokemon the player picked up.
  Screen = Struct.new(:held) do
    def pbHeldPokemon; held; end
  end

  # A gen-6 party panel, with the text it writes over its member.
  class Panel
    def initialize(text); @text = text; end
  end

  test "the first slot read names the box the PC opens on, then the slot: name, sex sign, level, place and panel" do
    pc(storage(["Caja 1"], [0, 0] => bulba)).pbUpdateOverlay(0)
    assert_equal [["Caja 1. " + slot_line("Bulba#{MALE}", 5, place(1, 1)), true]], SpeakCapture.log
  end

  test "the overlay redrawn on the same slot says nothing" do
    scene = opened(storage(["Caja 1"], [0, 0] => bulba))
    2.times { scene.pbUpdateOverlay(0) }
    assert_nothing_spoken
  end

  test "another slot of the box is read alone, at its row and column" do
    scene = opened(storage(["Caja 1"], [0, 0] => bulba, [0, 7] => char))
    scene.pbUpdateOverlay(7)
    assert_equal [slot_line("Char#{MALE}", 9, place(2, 2))], SpeakCapture.lines
  end

  test "an empty slot is said empty, with its place" do
    scene = opened(storage(["Caja 1"], [0, 0] => bulba))
    scene.pbUpdateOverlay(8)
    assert_equal [T.t(:pc_empty) + place(2, 3)], SpeakCapture.lines
  end

  test "a PC opened again reads the slot the cursor already sits on, naming its box" do
    kept = storage(["Caja 1"], [0, 0] => bulba)
    opened(kept).pbUpdateOverlay(8)
    SpeakCapture.clear
    pc(kept).pbUpdateOverlay(8)
    assert_equal ["Caja 1. " + T.t(:pc_empty) + place(2, 3)], SpeakCapture.lines
  end

  test "a box turned under the cursor is named before the slot" do
    kept = storage(["Caja 1", "Caja 2"], [0, 3] => bulba, [1, 3] => char)
    scene = pc(kept)
    scene.pbUpdateOverlay(3)
    kept.currentBox = 1
    SpeakCapture.clear
    scene.pbUpdateOverlay(3)
    assert_equal ["Caja 2. " + slot_line("Char#{MALE}", 9, place(1, 4))], SpeakCapture.lines
  end

  test "moving inside the box after a turn says the slot alone" do
    kept = storage(["Caja 1", "Caja 2"], [0, 3] => bulba, [1, 3] => char)
    scene = pc(kept)
    scene.pbUpdateOverlay(3)
    kept.currentBox = 1
    scene.pbUpdateOverlay(3)
    SpeakCapture.clear
    scene.pbUpdateOverlay(4)
    assert_equal [T.t(:pc_empty) + place(1, 5)], SpeakCapture.lines
  end

  test "a Pokemon in hand over another is read as a swap, the one in hand with the sign its panel shows" do
    scene = opened(storage(["Caja 1"], [0, 0] => Poke.build(:name => "Pidgey", :level => 3)))
    hold(scene, squirt)
    scene.pbUpdateOverlay(0)
    assert_equal [T.t(:pc_swap, :name => "Pidgey", :held => "Squirt#{MALE}") + place(1, 1)], SpeakCapture.lines
  end

  test "a Pokemon in hand over an empty slot offers to leave it there" do
    scene = opened(storage(["Caja 1"], [0, 0] => bulba))
    hold(scene, squirt)
    scene.pbUpdateOverlay(5)
    assert_equal [T.t(:pc_place, :held => "Squirt#{MALE}") + place(1, 6)], SpeakCapture.lines
  end

  test "an egg in hand has no sign, as its panel draws none" do
    scene = opened(storage(["Caja 1"], [0, 0] => bulba))
    hold(scene, egg(Poke.build(:name => "Huevo", :gender => 1)))
    scene.pbUpdateOverlay(5)
    assert_equal [T.t(:pc_place, :held => "Huevo") + place(1, 6)], SpeakCapture.lines
  end

  test "the party column reads its member at its place in the column, and does not name the box" do
    pc(storage(["Caja 1"])).pbUpdateOverlay(0, [bulba])
    assert_equal [slot_line("Bulba#{MALE}", 5, place(1, 1))], SpeakCapture.lines
  end

  test "each control says its own label" do
    scene = pc(storage(["Caja 1"]))
    { -1 => [T.t(:pc_box, :name => "Caja 1"), T.t(:pc_box_hint)].join(". "), -2 => T.t(:pc_team),
      -3 => T.t(:pc_close), -4 => T.t(:pc_prev), -5 => T.t(:pc_next) }.each do |selection, label|
      SpeakCapture.clear
      scene.pbUpdateOverlay(selection)
      assert_equal [label], SpeakCapture.lines, "control #{selection}"
    end
  end

  test "holding on a control does not repeat it" do
    scene = pc(storage(["Caja 1"]))
    scene.pbUpdateOverlay(-3)
    SpeakCapture.clear
    scene.pbUpdateOverlay(-3)
    assert_nothing_spoken
  end

  test "a genderless Pokemon has no sign to say" do
    pc(storage(["Caja 1"], [0, 0] => Poke.build(:name => "Magnet", :level => 20, :gender => 2))).pbUpdateOverlay(0)
    assert_equal ["Caja 1. " + slot_line("Magnet", 20, place(1, 1))], SpeakCapture.lines
  end

  test "a female Pokemon says her sign, and a shiny one its star after where it sits" do
    star = Poke.build(:name => "Brillo", :level => 11, :gender => 1, :shiny => true)
    scene = opened(storage(["Caja 1"], [0, 0] => bulba, [0, 1] => star))
    scene.pbUpdateOverlay(1)
    assert_equal [slot_line("Brillo#{FEMALE}", 11, place(1, 2), [T.t(:pk_shiny)] + rest)], SpeakCapture.lines
  end

  test "an egg in a box is only an egg, at its place" do
    scene = opened(storage(["Caja 1"], [0, 0] => bulba, [0, 2] => egg(Poke.build(:name => "Huevo", :level => 1))))
    scene.pbUpdateOverlay(2)
    assert_equal [T.t(:pty_egg) + place(1, 3)], SpeakCapture.lines
  end

  test "the stop past the party column's six slots is the Back button" do
    pc(storage(["Caja 1"])).pbUpdateOverlay(6, [bulba])
    assert_equal [T.t(:pc_back)], SpeakCapture.lines
  end

  test "an empty party slot is said empty, at its place in the column" do
    pc(storage(["Caja 1"])).pbUpdateOverlay(3, [bulba])
    assert_equal [T.t(:pc_empty) + place(2, 2)], SpeakCapture.lines
  end

  test "a row holds as many slots as the game's box is wide, else the shared six" do
    assert_equal 6, Party.box_columns, "with no box class to ask"
    { 8 => 8, 1 => 1, 0 => 6, -2 => 6, "8" => 6 }.each do |width, columns|
      with_box_width(width) { assert_equal columns, Party.box_columns, "BOX_WIDTH #{width.inspect}" }
    end
  end

  test "a slot's row and column follow the width of the game's box" do
    with_box_width(8) do
      pc(storage(["Caja 1"], [0, 7] => char)).pbUpdateOverlay(7)
      assert_equal ["Caja 1. " + slot_line("Char#{MALE}", 9, place(1, 8))], SpeakCapture.lines
    end
  end

  test "the party ends where the game's own party size says, else at the shared six" do
    assert_equal 6, Party.party_capacity, "with no function of the game's to ask"
    { 4 => 4, 1 => 1, 0 => 6, nil => 6 }.each do |size, capacity|
      GameFunctions.with(:max_party_size => lambda { size }) do
        assert_equal capacity, Party.party_capacity, "max_party_size #{size.inspect}"
      end
    end
  end

  test "the party column's Back button sits past the party the game shrank" do
    GameFunctions.with(:max_party_size => lambda { 4 }) do
      pc(storage(["Caja 1"])).pbUpdateOverlay(4, [bulba])
      assert_equal [T.t(:pc_back)], SpeakCapture.lines
    end
  end

  test "the slot says the rest of the panel: types, ability, held item and the marks as the signs it paints" do
    zap = Poke.build(:name => "Zap", :level => 30, :ability => 9, :item => 25)
    zap.define_singleton_method(:type1) { 13 }
    zap.define_singleton_method(:type2) { 2 }
    zap.define_singleton_method(:markings) { 0b1001 }
    with_marking_signs(["\xE2\x97\x8F", "\xE2\x96\xA0", "\xE2\x96\xB2", "\xE2\x99\xA5"]) do
      pc(storage(["Caja 1"], [0, 0] => zap)).pbUpdateOverlay(0)
      rest = [T.t(:pc_types, :t => "Tipo13 Tipo2"), T.t(:pc_ability, :a => "Habilidad9"), T.t(:pc_item, :i => "Repel"),
              T.t(:mk_list, :list => "\xE2\x97\x8F, \xE2\x99\xA5")]
      assert_equal ["Caja 1. " + slot_line("Zap#{MALE}", 30, place(1, 1), rest)], SpeakCapture.lines
    end
  end

  test "a Pokemon with no HP left is said fainted; one with HP to spare, or whose HP cannot be read, is not" do
    unread = Poke.build(:name => "Bulba", :level => 5)
    unread.define_singleton_method(:hp) { raise "no HP" }
    { "0 HP" => [Poke.build(:name => "Bulba", :level => 5, :hp => 0), ", " + T.t(:pk_fainted)],
      "1 HP" => [Poke.build(:name => "Bulba", :level => 5, :hp => 1), ""],
      "unreadable HP" => [unread, ""] }.each do |what, (pk, fainted)|
      SpeakCapture.clear
      pc(storage(["Caja 1"])).pbUpdateOverlay(0, [pk])
      assert_equal [T.t(:pc_slot, :name => "Bulba#{MALE}", :level => 5) + fainted + place(1, 1) + ", " + rest.join(", ")],
                   SpeakCapture.lines, what
    end
  end

  test "a panel with no ability or held item to show says so, and an item that names itself is said by its name" do
    nameless = Struct.new(:name).new("")
    berry = Struct.new(:name).new("Baya Aranja")
    none = [T.t(:pc_no_ability), T.t(:pc_no_item)]
    named = [T.t(:pc_ability, :a => "Habilidad1"), T.t(:pc_item, :i => "Baya Aranja")]
    { [0, 0] => none, [nameless, nameless] => none, [1, berry] => named }.each do |(ability, item), parts|
      pk = Poke.build(:name => "Bulba", :level => 5, :ability => ability, :item => item)
      SpeakCapture.clear
      pc(storage(["Caja 1"])).pbUpdateOverlay(0, [pk])
      assert_equal [slot_line("Bulba#{MALE}", 5, place(1, 1), parts)], SpeakCapture.lines, [ability, item].inspect
    end
  end

  test "a slot whose Pokemon cannot be read says nothing, and the next slot is still read" do
    broken = Object.new
    def broken.name; raise "unreadable"; end
    scene = opened(storage(["Caja 1"], [0, 0] => bulba, [0, 1] => broken))
    scene.pbUpdateOverlay(1)
    scene.pbUpdateOverlay(2)
    assert_equal [T.t(:pc_empty) + place(1, 3)], SpeakCapture.lines
  end

  test "back from a command menu, the slot is read again without its box" do
    scene = opened(storage(["Caja 7"], [0, 0] => bulba))
    scene.pbUpdateOverlay(1)
    PokeAccess.speak("Mover", true)
    scene.pbSelectBoxInternal(nil)
    SpeakCapture.clear
    scene.pbUpdateOverlay(1)
    assert_equal [T.t(:pc_empty) + place(1, 2)], SpeakCapture.lines
  end

  test "back in the party column from a command menu, its member is read again" do
    party = [bulba]
    scene = pc(storage(["Caja 1"]))
    scene.pbUpdateOverlay(0, party)
    PokeAccess.speak("Mover", true)
    scene.pbSelectPartyInternal(party, false)
    SpeakCapture.clear
    scene.pbUpdateOverlay(0, party)
    assert_equal [slot_line("Bulba#{MALE}", 5, place(1, 1))], SpeakCapture.lines
  end

  test "a selection loop entered again with its slot still the last thing said says nothing" do
    party = [bulba]
    loops = { :pbSelectBoxInternal => [[nil], nil], :pbSelectPartyInternal => [[party, false], party] }
    loops.each do |loop_name, (args, column)|
      scene = pc(storage(["Caja 1"], [0, 0] => bulba))
      scene.pbUpdateOverlay(0, column)
      scene.send(loop_name, *args)
      SpeakCapture.clear
      scene.pbUpdateOverlay(0, column)
      assert_nothing_spoken loop_name.to_s
    end
  end

  test "the box is named with the first slot read after a control, but not after its header" do
    { -1 => "", -2 => "Caja 7. " }.each do |control, lead|
      scene = pc(storage(["Caja 7"], [0, 0] => bulba))
      scene.pbUpdateOverlay(control)
      SpeakCapture.clear
      scene.pbUpdateOverlay(0)
      assert_equal [lead + slot_line("Bulba#{MALE}", 5, place(1, 1))], SpeakCapture.lines, "after control #{control}"
    end
  end

  test "a party slot is read again when another member takes its place" do
    party = [bulba, char, Poke.build(:name => "Pidgey", :level => 3)]
    scene = pc(storage(["Caja 1"]))
    scene.pbUpdateOverlay(1, party)
    party.delete_at(1)
    SpeakCapture.clear
    scene.pbUpdateOverlay(1, party)
    assert_equal [slot_line("Pidgey#{MALE}", 3, place(1, 2))], SpeakCapture.lines
  end

  test "a slot's Pokemon is the info key's, and Ctrl+T says its whole line without the box's name" do
    pk = bulba
    pc(storage(["Caja 1"], [0, 0] => pk)).pbUpdateOverlay(0)
    assert_equal [PokeAccess::Info.pokemon_info(pk), slot_line("Bulba#{MALE}", 5, place(1, 1))],
                 [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "at brief a slot says its Pokemon's name and level, while Ctrl+T keeps the whole line" do
    PokeAccess::Config.verbosity = :brief
    pc(storage(["Caja 1"], [0, 0] => bulba)).pbUpdateOverlay(0)
    assert_equal ["Caja 1. " + T.t(:pc_slot, :name => "Bulba", :level => 5)], SpeakCapture.lines
    assert_equal slot_line("Bulba#{MALE}", 5, place(1, 1)), PokeAccess::Info.row_text
  end

  test "a control is the info key's text and the row Ctrl+T says" do
    pc(storage(["Caja 1"])).pbUpdateOverlay(-3)
    assert_equal [T.t(:pc_close), T.t(:pc_close)], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "the party and close controls say the words the PC writes under the box, left to right, with that row's hints" do
    scene = pc(storage(["Caja 1"]))
    Party.announce_pc(scene, -2, nil, ROYAL_ROW)
    Party.announce_pc(scene, -3, nil, ROYAL_ROW)
    assert_equal ["Equipo: 3. [W]: Buscar", "Salir"], SpeakCapture.lines
  end

  test "with key hints left out, the party control says its painted word alone" do
    PokeAccess::Config.verbosity = :brief
    Party.announce_pc(pc(storage(["Caja 1"])), -2, nil, ROYAL_ROW)
    assert_equal ["Equipo: 3"], SpeakCapture.lines
  end

  test "moving onto a party member reads its name, sex sign, level and HP, cutting in" do
    scene = party_scene([healthy, fainted])
    Party.announce_party(scene, scene.party, 0, -1)
    assert_equal [[member("Bulba", MALE, 5, 20, 20), true]], SpeakCapture.log
  end

  test "a nicknamed member says the species its icon shows after the name, in full only; one without a nickname once" do
    plain = Poke.build(:name => "Especie1", :level => 5, :hp => 20, :totalhp => 20)
    lines = vb_levels { Party.party_line([healthy], 0) }
    assert_equal [T.t(:pty_member_nolv, :name => "Bulba", :sex => "", :hp => 20, :tot => 20),
                  T.t(:pty_member, :name => "Bulba", :sex => "", :level => 5, :hp => 20, :tot => 20),
                  member("Bulba", MALE, 5, 20, 20)], lines
    assert_equal T.t(:pty_member, :name => "Especie1", :sex => MALE, :level => 5, :hp => 20, :tot => 20),
                 Party.party_line([plain], 0)
  end

  test "the same party index twice is no move and says nothing" do
    scene = party_scene([healthy, fainted])
    Party.announce_party(scene, scene.party, 0, 0)
    assert_nothing_spoken
  end

  test "a party member with no HP left says it is fainted" do
    scene = party_scene([healthy, fainted])
    Party.announce_party(scene, scene.party, 1, 0)
    assert_equal [member("Char", FEMALE, 9, 0, 24) + ", " + T.t(:pk_fainted)], SpeakCapture.lines
  end

  test "a key press that leaves the party cursor where it was says nothing" do
    party_scene([healthy, fainted]).pbChangeSelection(Input::DOWN, 1)
    assert_nothing_spoken
  end

  test "each trailing button says the button its sprite is, confirm and cancel told apart" do
    { PokeSelectionCancelSprite => T.t(:pc_cancel), PokeSelectionConfirmSprite => T.t(:pc_confirm),
      PokeSelectionCancelSprite2 => T.t(:pc_cancel), nil => T.t(:pc_cancel) }.each do |sprite, word|
      scene = party_scene([healthy], sprite ? { "pokemon6" => sprite.new } : {})
      SpeakCapture.clear
      Party.announce_party(scene, scene.party, 6, 0)
      assert_equal [word], SpeakCapture.lines, sprite.inspect
    end
  end

  test "a panel's annotation, able or not able, takes the place of the HP" do
    unable = Poke.build(:name => "Char", :level => 9, :hp => 24, :totalhp => 24, :gender => 1)
    scene = party_scene([healthy, unable], "pokemon0" => Panel.new("APTO"), "pokemon1" => Panel.new("NO APTO"))
    Party.announce_party(scene, scene.party, 0, -1)
    Party.announce_party(scene, scene.party, 1, 0)
    assert_equal [head("Bulba", MALE, 5) + ", APTO", head("Char", FEMALE, 9) + ", NO APTO"], SpeakCapture.lines
  end

  test "an egg in the party is said as an egg, with the annotation its panel writes" do
    { nil => T.t(:pty_egg), "NO APTO" => "#{T.t(:pty_egg)}, NO APTO" }.each do |annotation, said|
      scene = party_scene([egg(healthy)], annotation ? { "pokemon0" => Panel.new(annotation) } : {})
      assert_equal [said, said], [Party.member_text(scene, scene.party, 0), PokeAccess::Info.row_text],
                   annotation.inspect
    end
  end

  test "the line says the state slot, the shiny star, the held item's icon and the Exp. Share mark the panel draws" do
    sleepy = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :status => 1, :item => 25,
                        :shiny => true)
    sleepy.define_singleton_method(:expshare) { true }
    sleepy.define_singleton_method(:pokerusStage) { 1 }
    mail = Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :item => 25)
    mail.define_singleton_method(:mail) { Object.new }
    icons = [T.t(:st_sleep), T.t(:pk_shiny), T.t(:pty_item), T.t(:pty_expshare)]
    assert_equal [member("Bulba", MALE, 5, 20, 20) + ", " + icons.join(", "),
                  member("Bulba", MALE, 5, 20, 20) + ", " + T.t(:pty_mail)],
                 [Party.party_line([sleepy], 0), Party.party_line([mail], 0)]
  end

  test "a party member at 1 HP is not fainted" do
    pk = Poke.build(:name => "Bulba", :level => 5, :hp => 1, :totalhp => 20)
    assert_equal member("Bulba", MALE, 5, 1, 20), Party.party_line([pk], 0)
  end

  test "pokerus fills an empty state slot on a v17-and-later panel, by its stage or by the counter older games keep" do
    { [:pokerusStage, 1] => true, [:pokerusStage, 2] => false, [:pokerusStage, 0] => false,
      [:pokerus, 1] => true, [:pokerus, 0] => false }.each do |(question, answer), carries|
      pk = Poke.build(:name => "Char", :level => 9, :hp => 24, :totalhp => 24)
      pk.define_singleton_method(question) { answer }
      said = member("Char", MALE, 9, 24, 24) + (carries ? ", " + T.t(:pk_pokerus) : "")
      assert_equal said, Party.member_line(pk, :pokerus_slot => true), "#{question} #{answer}"
    end
  end

  test "fainted takes the one state slot before any ailment or pokerus" do
    pk = Poke.build(:name => "Dead", :level => 9, :hp => 0, :totalhp => 24, :status => 1)
    pk.define_singleton_method(:pokerusStage) { 1 }
    assert_equal member("Dead", MALE, 9, 0, 24) + ", " + T.t(:pk_fainted),
                 Party.member_line(pk, :pokerus_slot => true)
  end

  test "a gen-6 party slot leaves pokerus out, as a v16 panel has no icon for it" do
    scene = party_scene([carrier])
    assert_equal member("Char", MALE, 9, 24, 24), Party.member_text(scene, scene.party, 0)
  end

  test "a gen-6 party slot says pokerus where the profile's panel draws it" do
    with_panel_pokerus(true) do
      scene = party_scene([carrier])
      assert_equal member("Char", MALE, 9, 24, 24) + ", " + T.t(:pk_pokerus),
                   Party.member_text(scene, scene.party, 0)
    end
  end

  test "a party line asked with no panel to go by leaves pokerus out" do
    assert_equal member("Char", MALE, 9, 24, 24), Party.party_line([carrier], 0)
  end

  test "an index outside the party is the cancel label" do
    [-1, 2].each { |idx| assert_equal T.t(:pc_cancel), Party.party_line([healthy, fainted], idx), "index #{idx}" }
  end

  test "a party member is the info key's Pokemon, and its line the row Ctrl+T says" do
    pk = carrier
    scene = party_scene([pk])
    Party.member_text(scene, scene.party, 0)
    assert_equal [PokeAccess::Info.pokemon_info(pk), member("Char", MALE, 9, 24, 24)],
                 [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "the button past the party is the info key's text and Ctrl+T's row" do
    scene = party_scene([carrier])
    assert_equal [T.t(:pc_cancel)] * 3,
                 [Party.member_text(scene, scene.party, 1), PokeAccess::Info.row_text, PokeAccess::Info.info_text]
  end

  test "the member the cursor rests on is read, queued, as the list takes a choice, and the info key has it" do
    pk = healthy
    PokemonScreen_Scene.new([pk, fainted]).pbChoosePokemon
    assert_equal [[member("Bulba", MALE, 5, 20, 20), false]], SpeakCapture.log
    assert_equal PokeAccess::Info.pokemon_info(pk), PokeAccess::Info.info_text
  end

  test "a forced switch reads the member it starts on" do
    PokemonScreen_Scene.new([healthy, fainted]).pbChoosePokemon(true, 1)
    assert_equal [member("Char", FEMALE, 9, 0, 24) + ", " + T.t(:pk_fainted)], SpeakCapture.lines
  end

  test "a choice that starts on the first member reads it, wherever the cursor was" do
    scene = PokemonScreen_Scene.new([healthy, fainted])
    scene.activecmd = 1
    scene.pbChoosePokemon(false, 0)
    assert_equal [member("Bulba", MALE, 5, 20, 20)], SpeakCapture.lines
  end

  test "a choice with no cursor to rest on says nothing" do
    [nil, -1].each do |cursor|
      scene = PokemonScreen_Scene.new([healthy, fainted])
      scene.activecmd = cursor
      scene.pbChoosePokemon
      assert_nothing_spoken "cursor #{cursor.inspect}"
    end
  end

  test "the party column says where each member sits in its two staggered columns of three" do
    party = [bulba, char, squirt]
    scene = pc(storage(["Caja 1"]))
    [0, 1, 2].each { |i| scene.pbUpdateOverlay(i, party) }
    assert_equal [slot_line("Bulba#{MALE}", 5, place(1, 1)), slot_line("Char#{MALE}", 9, place(1, 2)),
                  slot_line("Squirt#{MALE}", 7, place(2, 1))], SpeakCapture.lines
  end

  test "with a Pokemon in hand the info key reads the one in hand as the panel paints it, over a slot or a control" do
    scene = opened(storage(["Caja 1"], [0, 0] => Poke.build(:name => "Pidgey", :level => 3)))
    hold(scene, squirt)
    scene.pbUpdateOverlay(0)
    kept = [[PokeAccess::Info.info_text, PokeAccess::Info.row_text]]
    scene.pbUpdateOverlay(-3)
    kept.push([PokeAccess::Info.info_text, PokeAccess::Info.row_text])
    swap = T.t(:pc_swap, :name => "Pidgey", :held => "Squirt#{MALE}") + place(1, 1)
    assert_equal [[slot_line("Squirt#{MALE}", 7), swap], [slot_line("Squirt#{MALE}", 7), T.t(:pc_close)]], kept
  end

  test "a destination mode whose help line is kept off screen says that line as it starts, then its tinted origin" do
    scene = party_scene([healthy, fainted], "helpwindow" => help_window(1000))
    PokeAccess.say_party_help(scene, "Move to where?")
    assert_nothing_spoken "nothing while the line is only set"
    scene.pbChoosePokemon(true)
    assert_equal [["Move to where?", false], [member("Bulba", MALE, 5, 20, 20) + ", " + T.t(:swap_chosen), false]],
                 SpeakCapture.log
  end

  test "a help line on screen is said as it is set, and the mode's origin is tinted as it starts" do
    scene = party_scene([healthy, fainted], "helpwindow" => help_window(300))
    PokeAccess.say_party_help(scene, "Move to where?")
    scene.pbChoosePokemon(true)
    assert_equal ["Move to where?", member("Bulba", MALE, 5, 20, 20) + ", " + T.t(:swap_chosen)], SpeakCapture.lines
  end

  test "a destination mode entered again under the same line, and a plain choice, say no help line" do
    scene = party_scene([healthy, fainted], "helpwindow" => help_window(1000))
    PokeAccess.say_party_help(scene, "Use on which Pokémon?")
    scene.pbChoosePokemon(true, 1)
    SpeakCapture.clear
    scene.activecmd = 0
    scene.pbChoosePokemon(true, 1)
    PokeAccess.say_party_help(scene, "Choose a Pokémon.")
    scene.pbChoosePokemon
    assert_equal [member("Char", FEMALE, 9, 0, 24) + ", " + T.t(:pk_fainted)] * 2, SpeakCapture.lines
  end

  test "moving onto a destination mode's origin says the tint its panel wears; a plain choice does not" do
    scene = party_scene([healthy, fainted], "pokemon0" => tinted(true), "pokemon1" => tinted(false))
    Party.announce_party(scene, scene.party, 0, 1)
    scene.activecmd = 0
    scene.pbChoosePokemon
    assert_equal [member("Bulba", MALE, 5, 20, 20) + ", " + T.t(:swap_chosen), member("Bulba", MALE, 5, 20, 20)],
                 SpeakCapture.lines
  end

  test "an egg as a destination mode's origin is said tinted" do
    scene = party_scene([egg(healthy)], "pokemon0" => tinted(true))
    assert_equal "#{T.t(:pty_egg)}, #{T.t(:swap_chosen)}", Party.member_text(scene, scene.party, 0)
  end

  private

  # The party screen's help window, kept at y.
  def help_window(y)
    Struct.new(:visible, :y, :text).new(true, y, "")
  end

  # A party panel wearing a destination mode's origin tint, or not.
  def tinted(flag)
    Struct.new(:preselected).new(flag)
  end

  # What the box panel shows of a stand-in Pokemon besides name, level and place: Poke.build's ability, no item.
  def rest
    [T.t(:pc_ability, :a => "Habilidad1"), T.t(:pc_no_item)]
  end

  # The stand-in Pokemon the tests share, each built anew.
  def bulba; Poke.build(:name => "Bulba", :level => 5); end
  def char; Poke.build(:name => "Char", :level => 9); end
  def squirt; Poke.build(:name => "Squirt", :level => 7); end
  def healthy; Poke.build(:name => "Bulba", :level => 5, :hp => 20, :totalhp => 20, :gender => 0); end
  def fainted; Poke.build(:name => "Char", :level => 9, :hp => 0, :totalhp => 24, :gender => 1); end

  # A healthy member at pokerus stage 1.
  def carrier
    pk = Poke.build(:name => "Char", :level => 9, :hp => 24, :totalhp => 24)
    pk.define_singleton_method(:pokerusStage) { 1 }
    pk
  end

  # pk, answering as an egg.
  def egg(pk)
    def pk.egg?; true; end
    pk
  end

  # A storage of named boxes whose slots hold mons ({[box, index] => pokemon}), open on the first box.
  def storage(names, mons = {})
    Storage.new(names, mons, 0)
  end

  # The gen-6 PC box screen over a storage, nothing in hand.
  def pc(kept)
    scene = PokemonStorageScene.new
    scene.instance_variable_set(:@screen, Screen.new(nil))
    scene.instance_variable_set(:@storage, kept)
    scene
  end

  # The PC opened on its first slot, that first reading cleared.
  def opened(kept)
    scene = pc(kept)
    scene.pbUpdateOverlay(0)
    SpeakCapture.clear
    scene
  end

  # Puts pk in the player's hand on the PC's screen.
  def hold(scene, pk)
    scene.instance_variable_get(:@screen).held = pk
  end

  # The gen-6 party screen over party, with the given sprites (panels and buttons by "pokemon<index>").
  def party_scene(party, sprites = {})
    scene = PokemonScreen_Scene.new(party)
    scene.sprites = sprites
    scene
  end

  # ", row r column c" as the PC says where a slot sits.
  def place(row, col)
    T.t(:pc_pos, :row => row, :col => col)
  end

  # A stored Pokemon's line: its name as shown, level and place, then the rest of its panel.
  def slot_line(name, level, where = "", parts = rest)
    T.t(:pc_slot, :name => name, :level => level) + where + ", " + parts.join(", ")
  end

  # A party member's line: name, the species its icon shows after the nickname (species 1's), sex sign, level and HP.
  def member(name, sex, level, hp, total)
    T.t(:pty_member, :name => "#{name}, Especie1", :sex => sex, :level => level, :hp => hp, :tot => total)
  end

  # A party member's head as an annotated panel shows it: name, the species after the nickname, sex sign and level.
  def head(name, sex, level)
    T.t(:pty_head, :name => "#{name}, Especie1", :sex => sex, :level => level)
  end

  # Runs the block with the game's PokemonBox::BOX_WIDTH at width (the module made if the game has none), then puts
  # back what stood there.
  def with_box_width(width)
    made = !defined?(PokemonBox)
    Object.const_set(:PokemonBox, Module.new) if made
    had = PokemonBox.const_defined?(:BOX_WIDTH, false)
    old = had ? PokemonBox::BOX_WIDTH : nil
    PokemonBox.send(:remove_const, :BOX_WIDTH) if had
    PokemonBox.const_set(:BOX_WIDTH, width)
    yield
  ensure
    PokemonBox.send(:remove_const, :BOX_WIDTH) if defined?(PokemonBox) && PokemonBox.const_defined?(:BOX_WIDTH, false)
    PokemonBox.const_set(:BOX_WIDTH, old) if had
    Object.send(:remove_const, :PokemonBox) if made && defined?(PokemonBox)
  end

  # Runs the block with the gen-6 PC's marking signs (PokemonStorage::MARKINGCHARS) set to signs.
  def with_marking_signs(signs)
    made = !defined?(PokemonStorage)
    Object.const_set(:PokemonStorage, Class.new) if made
    PokemonStorage.const_set(:MARKINGCHARS, signs)
    yield
  ensure
    PokemonStorage.send(:remove_const, :MARKINGCHARS) if defined?(PokemonStorage)
    Object.send(:remove_const, :PokemonStorage) if made && defined?(PokemonStorage)
  end

  # Runs the block with this game's party panel drawing pokerus in its state slot or not, as a profile declares it.
  def with_panel_pokerus(drawn)
    meta = (class << Party; self; end)
    meta.send(:alias_method, :spec_panel_pokerus?, :panel_pokerus?)
    Party.define_singleton_method(:panel_pokerus?) { drawn }
    yield
  ensure
    meta.send(:alias_method, :panel_pokerus?, :spec_panel_pokerus?)
    meta.send(:remove_method, :spec_panel_pokerus?)
  end
end
