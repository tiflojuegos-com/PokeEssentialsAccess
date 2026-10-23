# The field readers (mail, money window, hidden item, berry plant, phone, fishing bite, dex figure, tip card, book,
# achievement): the line each says for what the game hands over, and the hooks that hand it over.

# The game functions the readers wrap. The mail card and the fishing wait answer what had been said as they began.
def pbDisplayMail(_mail, _bearer = nil)
  SpeakCapture.lines.dup
end

def pbWaitForInput(_msgwindow, _message, _frames)
  SpeakCapture.lines.dup
end

def pbClosestHiddenItem
  items = $game_map.events.values.select { |e| e.name =~ /hiddenitem/i }
  items.min_by { |e| (e.x - $game_player.x).abs + (e.y - $game_player.y).abs }
end

def pbDisplayGoldWindow(_msgwindow)
  Window_AdvancedTextPokemon.new(_INTL("Dinero:\n<ar>{1}</ar>", "$1.234"))
end

def pbShowCommands(_msgwindow, _commands = nil, _cmd_if_cancel = 0, default_cmd = 0)
  default_cmd
end

# The phone's contact list as the game builds it: the names in @commands, the cursor at index.
class Window_PhoneList
  attr_accessor :index

  def initialize(commands, index)
    @commands = commands
    @index = index
  end
end

# The Tip Cards addon's single-card screen: pbDrawTip paints the card at @index of @tips.
class TipCard_Scene
  def initialize(tips)
    @tips = tips
    @index = 0
    @pages = tips.length
  end

  def pbDrawTip; :drawn; end
end

# The addon's grouped browser: pbDrawGroup opens the group in focus at its first card and draws it, pbDrawTip draws the
# card in focus, and pbScene runs the frames a test hands it, answering what each returned.
class TipCardGroups_Scene
  attr_accessor :index, :section

  def initialize(groups, frames = [])
    @groups = groups
    @section = 0
    @index = 0
    @frames = frames
  end

  def pbDrawGroup
    @tips = ::Settings::TIP_CARDS_GROUPS[@groups[@section]][:Tips]
    @pages = @tips.length
    @index = 0
    pbDrawTip
  end

  def pbDrawTip; :drawn; end

  def pbScene
    @frames.map { |frame| frame.call(self) }
  end
end

# A readable book as the game builds it: pbBook opens one and texto paints its open page every frame, here one frame
# for each page a test turns to.
class BookScene
  def pbBook(libro, pages)
    @libro = libro
    pages.each do |page|
      @page = page
      texto
    end
    :closed
  end

  def texto; :painted; end
end

# Binds the readers' hooks to the stand-ins above, evaluating again only the code after each file's module, so the
# module itself keeps the coverage of its first load.
%w[core/field/mail.rb core/field/fishing.rb core/field/itemfinder.rb core/menus/money_window.rb
   plugins/tip_cards.rb plugins/book_scene.rb].each do |rel|
  src = Harness.source(File.join(Harness::ROOT, rel))
  readers = src[/\Amodule PokeAccess\n.*?^end\n/m]
  eval(src[readers.length..-1], TOPLEVEL_BINDING, "hooks of #{rel}", readers.count("\n") + 1)
end

class FieldHelpersTest < PokeAccessTest
  Mail = Struct.new(:message, :sender)
  TextWindow = Struct.new(:text)
  Spot = Struct.new(:x, :y)
  PlantEvent = Struct.new(:variable)
  Achievement = Struct.new(:name, :status, :desc)
  BerryPlant = Struct.new(:growth_stage, :berry_id, :moisture_stage, :new_mechanics) do
    def planted?; growth_stage > 0; end
  end
  Contact = Struct.new(:ready) do
    def can_rematch?; ready; end
  end
  CARDS = { :swim => { :Title => "Como nadar", :Text => "Usa <b>Surf</b> en el agua." },
            :fly => { :Title => "Como volar", :Text => "Usa Vuelo fuera de combate." } }.freeze
  GROUPS = { :basics => { :Title => "Lo basico", :Tips => [:swim] },
             :battle => { :Title => "Combate", :Tips => [:fly, :swim] } }.freeze
  SWIM = "Como nadar. Usa Surf en el agua."
  FLY = "Como volar. Usa Vuelo fuera de combate."
  BITE_LINE = "¡Oh! ¡Ha picado algo!"
  TIP_CARDS = File.join(Harness::ROOT, "plugins", "tip_cards.rb")

  test "says a mail's body, then who sent it" do
    assert_equal "Hola. #{t(:mail_from, :name => 'Rojo')}", PokeAccess.mail_text(Mail.new("Hola", "Rojo"))
  end

  test "says the body or the sender alone when the mail has only one of them" do
    from = t(:mail_from, :name => "Rojo")
    { ["Hola", nil] => "Hola", ["Hola", "  "] => "Hola", [nil, "Rojo"] => from, [" ", "Rojo"] => from }.each do |(body, sender), want|
      assert_equal want, PokeAccess.mail_text(Mail.new(body, sender)), "body #{body.inspect}, sender #{sender.inspect}"
    end
  end

  test "gives nothing for a mail with neither body nor sender, or for no mail" do
    [Mail.new("", ""), Mail.new(" \n", nil), nil].each { |mail| assert_nil PokeAccess.mail_text(mail), mail.inspect }
  end

  test "cleans the codes and markup out of a mail's body" do
    assert_equal "Hola amigo", PokeAccess.mail_text(Mail.new("\\c[2]Hola <b>amigo</b>", nil))
  end

  test "says what it can read of a mail whose body or sender cannot be read" do
    no_body = Mail.new(nil, "Rojo")
    def no_body.message; raise "corrupt"; end
    no_sender = Mail.new("Hola", nil)
    def no_sender.sender; raise "corrupt"; end
    [[no_body, t(:mail_from, :name => "Rojo"), "body unreadable"], [no_sender, "Hola", "sender unreadable"]].each do |mail, want, what|
      assert_equal want, PokeAccess.mail_text(mail), what
    end
  end

  test "reads a mail before its card shows, interrupting" do
    line = "Hola. #{t(:mail_from, :name => 'Rojo')}"
    heard = pbDisplayMail(Mail.new("Hola", "Rojo"))
    assert_equal [[line, true]], SpeakCapture.log
    assert_equal [line], heard, "said by the time the card showed"
  end

  test "shows a mail with nothing to read in silence" do
    pbDisplayMail(Mail.new("", nil))
    assert_nothing_spoken
  end

  test "says a money window's label and amount on one line" do
    { "Dinero:\n<ar>$1.234</ar>" => "Dinero: $1.234", "Dinero:<AR>$1.234</AR>" => "Dinero: $1.234",
      "Fichas:\r\n<ar>50</ar>" => "Fichas: 50" }.each do |painted, want|
      assert_equal want, PokeAccess.money_window_text(TextWindow.new(painted)), painted.inspect
    end
  end

  test "gives nothing for a money window with no text, or none it can read" do
    [TextWindow.new(""), TextWindow.new(nil), Object.new].each { |win| assert_nil PokeAccess.money_window_text(win), win.inspect }
  end

  test "reads the money window the game opens, queued after the message line" do
    pbDisplayGoldWindow(nil)
    assert_equal [["Dinero: $1.234", false]], SpeakCapture.log
  end

  test "says nothing for a money window with nothing in it" do
    PokeAccess.say_money_window(TextWindow.new(""))
    assert_nothing_spoken
  end

  test "says how many steps away a hidden item is and which way, up or down first" do
    { [5, 2] => [3, [:dir_up]], [5, 6] => [1, [:dir_down]], [3, 5] => [2, [:dir_left]], [6, 5] => [1, [:dir_right]],
      [7, 3] => [4, [:dir_up, :dir_right]], [4, 8] => [4, [:dir_down, :dir_left]] }.each do |(x, y), (steps, dirs)|
      want = t(:if_direction, :n => steps, :dir => dirs.map { |d| t(d) }.join(" "))
      assert_equal want, PokeAccess.hidden_item_text(Spot.new(x, y)), "the item at (#{x}, #{y}), the player at (5, 5)"
    end
  end

  test "says a hidden item on the player's own tile is right underfoot" do
    assert_equal t(:if_underfoot), PokeAccess.hidden_item_text(Spot.new(5, 5))
  end

  test "gives no way to a hidden item without the item, or without a player" do
    player = $game_player
    assert_nil PokeAccess.hidden_item_text(nil), "no item"
    $game_player = nil
    assert_nil PokeAccess.hidden_item_text(Spot.new(5, 2)), "no player"
  ensure
    $game_player = player
  end

  test "says the way to the hidden item the Itemfinder finds, interrupting" do
    World.event(:id => 7, :name => "HiddenItem", :x => 5, :y => 2)
    pbClosestHiddenItem
    assert_equal [[t(:if_direction, :n => 3, :dir => t(:dir_up)), true]], SpeakCapture.log
  end

  test "says nothing when the Itemfinder finds no hidden item" do
    pbClosestHiddenItem
    assert_nothing_spoken
  end

  test "names a berry plant's growth stage, from the fifth on ready to pick" do
    { 1 => :berry_planted, 2 => :berry_sprouted, 3 => :berry_taller, 4 => :berry_flowering, 5 => :berry_ready,
      6 => :berry_ready }.each do |stage, word|
      assert_equal ", #{t(word)}", suffix(BerryPlant.new(stage, nil, nil, false)), "stage #{stage}"
    end
  end

  test "says a plant's stage, then its berry as the game names it, then its soil's moisture" do
    plants = { "gen-4 soil" => gen4_soil(5, 7, 80), "modern plant" => BerryPlant.new(5, :ORANBERRY, 2, true) }
    with_item_names(7 => "Baya Aranja", :ORANBERRY => "Baya Aranja") do
      plants.each do |shape, data|
        assert_equal ", #{t(:berry_ready)}, Baya Aranja, #{t(:berry_wet)}", suffix(data), shape
      end
    end
  end

  test "leaves out the berry of an empty slot, a plant with no berry id, and one the game cannot name or names blank" do
    berries = { 0 => "empty slot", nil => "no berry id", 8 => "a berry the game cannot name", 9 => "a berry named blank" }
    with_item_names(0 => "Ninguno", 9 => "") do
      berries.each { |berry, what| assert_equal ", #{t(:berry_taller)}", suffix(gen3_soil(3, berry)), what }
    end
  end

  test "says the rest of a modern plant whose berry cannot be read" do
    plant = BerryPlant.new(5, :ORANBERRY, 2, true)
    def plant.berry_id; raise "corrupt"; end
    with_item_names(:ORANBERRY => "Baya Aranja") do
      assert_equal ", #{t(:berry_ready)}, #{t(:berry_wet)}", suffix(plant)
    end
  end

  test "grades a gen-4 soil's moisture as the game's moisture sprite does" do
    { 0 => :berry_dry, 1 => :berry_damp, 50 => :berry_damp, 51 => :berry_wet, 100 => :berry_wet }.each do |water, word|
      assert_equal ", #{t(:berry_flowering)}, #{t(word)}", suffix(gen4_soil(4, 0, water)), "moisture #{water}"
    end
  end

  test "says no moisture for a gen-3 soil, whose mechanics keep none" do
    assert_equal ", #{t(:berry_flowering)}", suffix(gen3_soil(4, 0, 60))
  end

  test "says a modern plant's moisture under the new mechanics only" do
    { true => ", #{t(:berry_flowering)}, #{t(:berry_wet)}", false => ", #{t(:berry_flowering)}" }.each do |newmech, want|
      assert_equal want, suffix(BerryPlant.new(4, nil, 2, newmech)), "new mechanics #{newmech}"
    end
  end

  test "says no moisture for a modern plant whose moisture is off the scale, cannot be read, or whose mechanics cannot" do
    odd = BerryPlant.new(4, nil, 3, true)
    unread = BerryPlant.new(4, nil, 2, true)
    def unread.moisture_stage; raise "corrupt"; end
    unknown = BerryPlant.new(4, nil, 2, true)
    def unknown.new_mechanics; raise "corrupt"; end
    [[odd, "off the scale"], [unread, "moisture unreadable"], [unknown, "mechanics unreadable"]].each do |plant, what|
      assert_equal ", #{t(:berry_flowering)}", suffix(plant), what
    end
  end

  test "says nothing for soil with no plant, with one it cannot read, or holding something else" do
    unsure = BerryPlant.new(3, :ORANBERRY, 2, true)
    def unsure.planted?; raise "corrupt"; end
    stageless = BerryPlant.new(3, :ORANBERRY, 2, true)
    def stageless.planted?; true; end
    def stageless.growth_stage; raise "corrupt"; end
    [[nil, "no data"], [gen3_soil(0, 0), "gen-3 empty soil"], [gen4_soil(0, 0, 0), "gen-4 empty soil"],
     [gen3_soil(nil, 7), "no stage"], [BerryPlant.new(0, :ORANBERRY, 2, true), "modern unplanted"],
     [unsure, "modern, planted unreadable"], [stageless, "modern, stage unreadable"], [7, "a number"],
     ["5", "a word"], [{ 0 => 5 }, "a table"]].each do |data, what|
      assert_equal "", suffix(data), what
    end
  end

  test "says nothing for an event that holds no plant data" do
    [[Object.new, "an event with no variable"], [nil, "no event"]].each do |event, what|
      assert_equal "", PokeAccess::Berry.state_suffix(event), what
    end
  end

  test "lists a plant's state as separate parts for the berry pots, none for unplanted soil" do
    with_item_names(7 => "Baya Aranja") do
      assert_equal [t(:berry_ready), "Baya Aranja", t(:berry_wet)], PokeAccess::Berry.state_parts(gen4_soil(5, 7, 80))
    end
    assert_equal [], PokeAccess::Berry.state_parts(gen3_soil(0, 0)), "unplanted soil"
  end

  test "marks a contact ready for a rematch after its name in the phone's list" do
    on_phone(:@contacts => [Contact.new(true), Contact.new(false)]) do
      assert_equal ["Joven Pepe, #{t(:phone_rematch)}", "Dama Ana"], [0, 1].map { |i| phone_row(i) }
    end
  end

  test "reads the gen-6 phone's trainers as ready when their fourth slot says so" do
    trainers = [[1, "Pepe", 5, true], [1, "Ana", 5, false], [0, "Mama", 5], "Joven Pepe"]
    on_phone(:@trainers => trainers) do
      { 0 => true, 1 => false, 2 => false, 3 => false, 4 => false }.each do |i, want|
        assert_equal want, PokeAccess::Phone.rematch_ready?(i), "trainer #{i}: #{trainers[i].inspect}"
      end
    end
  end

  test "has no contact ready on a phone whose contacts it cannot read" do
    broken = Contact.new(true)
    def broken.can_rematch?; raise "corrupt"; end
    [[{ :@contacts => [broken] }, "a contact that raises"], [{ :@contacts => Object.new }, "a list it cannot index"],
     [{}, "a phone that lists no one"]].each do |ivars, what|
      on_phone(ivars) { assert_equal false, PokeAccess::Phone.rematch_ready?(0), what }
    end
  end

  test "has no contact ready while no phone is open" do
    assert_equal [false, "Joven Pepe"], [PokeAccess::Phone.rematch_ready?(0), phone_row(0)]
  end

  test "holds the gen-6 phone while it runs, and lets go of it when it returns" do
    seen = []
    walk = Object.new
    walk.define_singleton_method(:each) { |&_step| seen.push(PokeAccess::Phone.rematch_ready?(0)) }
    phone = PokemonPhoneScene.new
    phone.instance_variable_set(:@trainers, [[1, "Pepe", 5, true]])
    phone.nav = walk
    assert_equal :phone_done, phone.start, "the phone runs as the game's"
    assert_equal [[true], false], [seen, PokeAccess::Phone.rematch_ready?(0)], "ready while it ran, not after"
  ensure
    PokeAccess::Phone.unwatch
  end

  test "announces the bite as the reflex test starts, keeping the game's own line for the repeat key" do
    heard = pbWaitForInput(nil, BITE_LINE, 20)
    assert_equal [[t(:fish_bite), true]], SpeakCapture.log
    assert_equal [[t(:fish_bite)], BITE_LINE], [heard, PokeAccess.last_dialogue], "said as the wait began, the game's line kept"
  end

  test "says nothing of the bite where the game hooks the fish by itself" do
    { true => [], false => [[t(:fish_bite), true]] }.each do |auto, want|
      SpeakCapture.clear
      with_consts(Object, :FISHINGAUTOHOOK => auto) { pbWaitForInput(nil, BITE_LINE, 20) }
      assert_equal want, SpeakCapture.log, "FISHINGAUTOHOOK #{auto}"
    end
  end

  test "says a dex figure with one decimal and the language's separator" do
    { :es => ["60,5", "1,5", "0,7"], :en => ["60.5", "1.5", "0.7"] }.each do |lang, want|
      PokeAccess::Config.language = lang
      dex = PokeAccess::Pokedex
      assert_equal want, [dex.fmt_float(60.5), dex.fmt_dec(15), dex.fmt_dec(7)], lang.inspect
    end
  end

  test "says a dex figure it cannot divide as it came" do
    assert_equal ["", "?"], [PokeAccess::Pokedex.fmt_dec(nil), PokeAccess::Pokedex.fmt_dec("?")]
  end

  test "gives no ribbon for a slot with no ribbon id" do
    assert_nil PokeAccess::Summary.ribbon_parts(nil)
  end

  test "reads the focused tip card's title and body, its markup cleaned" do
    with_tip_cards(CARDS) do
      assert_equal SWIM, PokeAccess.tip_card_text(tip_scene([:swim], 0))
    end
  end

  test "says a tip card's place among the cards, from the medium level" do
    entry = t(:list_entry, :name => FLY, :n => 2, :tot => 2)
    with_tip_cards(CARDS) do
      assert_equal [FLY, entry, entry], vb_levels { PokeAccess.tip_card_text(tip_scene([:swim, :fly], 1)) }
    end
  end

  test "counts the pages the addon keeps rather than its cards" do
    scene = World.stub_scene(:@tips => [:swim], :@index => 0, :@pages => 3)
    with_tip_cards(CARDS) do
      assert_equal t(:list_entry, :name => SWIM, :n => 1, :tot => 3), PokeAccess.tip_card_text(scene)
    end
  end

  test "reads a tip card through the game's own translation" do
    with_tip_cards(CARDS) do
      with_intl("Como nadar" => "How to swim", "Usa <b>Surf</b> en el agua." => "Use <b>Surf</b> on the water.") do
        assert_equal "How to swim. Use Surf on the water.", PokeAccess.tip_card_text(tip_scene([:swim], 0))
      end
    end
  end

  test "leaves out a part of a tip card the game translates to nothing" do
    with_tip_cards(CARDS) do
      with_intl("Como nadar" => "") do
        assert_equal "Usa Surf en el agua.", PokeAccess.tip_card_text(tip_scene([:swim], 0))
      end
    end
  end

  test "names the key the player moved in a tip card's body" do
    with_c_on_k do
      with_tip_cards(:dash => { :Title => "Correr", :Text => "Pulsa la tecla C para correr." }) do
        assert_equal "Correr. Pulsa la tecla K para correr.", PokeAccess.tip_card_text(tip_scene([:dash], 0))
      end
    end
  end

  test "reads a tip card that has only a title, or only a body" do
    { { :Title => "Como nadar" } => "Como nadar", { :Title => "", :Text => "Usa Surf." } => "Usa Surf." }.each do |card, want|
      with_tip_cards(:swim => card) { assert_equal want, PokeAccess.tip_card_text(tip_scene([:swim], 0)), card.inspect }
    end
  end

  test "gives no tip card past the end, unknown to the addon, without text, or without the addon" do
    assert_nil PokeAccess.tip_card_text(tip_scene([:swim], 0)), "no addon tables"
    with_tip_cards(CARDS.merge(:blank => { :Title => "", :Text => nil })) do
      { [[:swim], 5] => "past the end", [[:dive], 0] => "unknown card", [[:blank], 0] => "no text",
        [nil, 0] => "no cards", [Object.new, 0] => "cards it cannot index" }.each do |(tips, i), what|
        assert_nil PokeAccess.tip_card_text(tip_scene(tips, i)), what
      end
    end
  end

  test "names the tip-card group in focus as the game translates it" do
    with_tip_cards(CARDS, :basics => { :Title => "Lo basico" }, :battle => { :Title => "Combate" }) do
      scene = World.stub_scene(:@groups => [:basics, :battle], :@section => 1)
      assert_equal "Battle", with_intl("Combate" => "Battle") { PokeAccess.tip_group_title(scene) }
    end
  end

  test "gives no group title without groups, a section, a group the addon knows or its title" do
    with_tip_cards(CARDS, :battle => { :Title => "Combate" }, :untitled => {}, :blank => { :Title => "" }) do
      { [nil, 0] => "no groups", [{ 0 => :battle }, 0] => "groups that are no list", [[:battle], nil] => "no section",
        [[:battle], 3] => "past the end", [[:dive], 0] => "unknown group", [[:untitled], 0] => "no title",
        [[:blank], 0] => "blank title" }.each do |(groups, sec), what|
        assert_nil PokeAccess.tip_group_title(World.stub_scene(:@groups => groups, :@section => sec)), what
      end
    end
  end

  test "reads the tip card as its screen draws it, interrupting" do
    with_tip_cards(CARDS) { TipCard_Scene.new([:swim]).pbDrawTip }
    assert_equal [[SWIM, true]], SpeakCapture.log
  end

  test "leads with the group's title as the grouped browser opens a group" do
    with_tip_cards(CARDS, GROUPS) { TipCardGroups_Scene.new([:basics, :battle]).pbDrawGroup }
    assert_equal [["Lo basico. #{SWIM}", true]], SpeakCapture.log
  end

  test "leads with the new group's title as the browser moves to another group" do
    scene = TipCardGroups_Scene.new([:basics, :battle])
    with_tip_cards(CARDS, GROUPS) do
      scene.pbDrawGroup
      SpeakCapture.clear
      scene.section = 1
      scene.pbDrawGroup
    end
    assert_equal [["Combate. #{t(:list_entry, :name => FLY, :n => 1, :tot => 2)}", true]], SpeakCapture.log
  end

  test "reads only the card as a page turns within the group" do
    scene = TipCardGroups_Scene.new([:battle])
    with_tip_cards(CARDS, GROUPS) do
      scene.pbDrawGroup
      SpeakCapture.clear
      scene.index = 1
      scene.pbDrawTip
    end
    assert_equal [[t(:list_entry, :name => SWIM, :n => 2, :tot => 2), true]], SpeakCapture.log
  end

  test "says a group's title alone when its card has nothing to read" do
    with_tip_cards(CARDS.merge(:art => { :Title => "<b></b>" }), :gallery => { :Title => "Galeria", :Tips => [:art] }) do
      TipCardGroups_Scene.new([:gallery]).pbDrawGroup
    end
    assert_equal [["Galeria", true]], SpeakCapture.log
  end

  test "holds the grouped browser while its loop runs, and lets go of it after" do
    scene = TipCardGroups_Scene.new([:basics], [lambda { |_s| PokeAccess::TipCards.group_scene }])
    held = scene.pbScene
    assert_same scene, held[0], "while its loop runs"
    assert_nil PokeAccess::TipCards.group_scene, "after it"
  ensure
    PokeAccess::TipCards.group_off
  end

  test "reads the focused card again as the group list closes inside the browser, handing the game its choice" do
    frames = [lambda { |s| s.pbDrawGroup }, lambda { |_s| pbShowCommands(nil, ["Lo basico", "Combate"], -1, 1) }]
    answers = with_tip_cards(CARDS, GROUPS) { TipCardGroups_Scene.new([:basics, :battle], frames).pbScene }
    assert_equal [["Lo basico. #{SWIM}", true], [SWIM, true]], SpeakCapture.log
    assert_equal 1, answers[1], "the game gets the group picked"
  ensure
    PokeAccess::TipCards.group_off
  end

  test "reads nothing as a command list closes outside the grouped browser" do
    pbShowCommands(nil, ["Si", "No"])
    assert_nothing_spoken
  end

  test "leaves the group list unwrapped where the addon turns it off" do
    with_tip_cards(CARDS, {}, :TIP_CARDS_GROUP_LIST => false) do
      assert_equal 0, group_list_wraps_added, "no body added to pbShowCommands"
    end
  end

  test "reads the page a book is open at, its markup cleaned" do
    book = ["Pagina uno con <b>negrita</b>.", "Pagina dos."]
    assert_equal ["Pagina uno con negrita.", "Pagina dos."], [0, 1].map { |page| PokeAccess.book_text(book, page) }
  end

  test "gives no book page past the end, an empty one, or without a book or a page" do
    book = ["Pagina uno.", ""]
    { [book, 9] => "past the end", [book, 1] => "empty page", [nil, 0] => "no book", [book, nil] => "no page" }.each do |(b, page), what|
      assert_nil PokeAccess.book_text(b, page), what
    end
  end

  test "reads a book's open page once while it stays, and the next as it turns, interrupting" do
    BookScene.new.pbBook(["Pagina uno.", "Pagina <b>dos</b>."], [0, 0, 1])
    assert_equal [["Pagina uno.", true], ["Pagina dos.", true]], SpeakCapture.log
  end

  test "says an achievement's name, its state and its description" do
    { 3 => :ach_done, 2 => :ach_pending, 1 => :ach_locked }.each do |status, word|
      assert_equal "Pescador, #{t(word)}. Pesca 10.",
                   PokeAccess.logro_indexed_text(Achievement.new("Pescador", status, "Pesca 10.")), "status #{status}"
    end
  end

  test "leaves an achievement's description to the full level, the info key keeping it at every level" do
    head = "Campeon, #{t(:ach_done)}"
    whole = "#{head}. Vence a la Liga."
    said = vb_levels { [PokeAccess.logro_indexed_text(Achievement.new("Campeon", 3, "Vence a la Liga.")), PokeAccess::Info.info_text] }
    assert_equal [[head, whole], [head, whole], [whole, whole]], said
  end

  test "says an achievement without a description by its name and state" do
    [nil, ""].each do |desc|
      assert_equal "Campeon, #{t(:ach_done)}", PokeAccess.logro_indexed_text(Achievement.new("Campeon", 3, desc)), desc.inspect
    end
  end

  test "cleans the codes and markup out of an achievement's description" do
    assert_equal "Campeon, #{t(:ach_done)}. Vence a la Liga.",
                 PokeAccess.logro_indexed_text(Achievement.new("Campeon", 3, "\\c[2]Vence a la <b>Liga</b>."))
  end

  test "names the key the player moved in an achievement's description" do
    with_c_on_k do
      assert_equal "Cofre, #{t(:ach_pending)}. Pulsa la tecla K para abrirlo.",
                   PokeAccess.logro_indexed_text(Achievement.new("Cofre", 2, "Pulsa la tecla C para abrirlo."))
    end
  end

  test "says a hidden achievement showing its copy's placeholder as painted, at every level and on the info key" do
    hidden = Achievement.new("????", 1, "Este es un logro oculto, ¡suerte en su búsqueda!")
    painted = "????. Este es un logro oculto, ¡suerte en su búsqueda!"
    [{ :NOMBREOCULTO => "????" }, { :Logros => logros_module(:NOMBREOCULTO => "????") }].each do |copy|
      with_consts(Object, copy) do
        assert_equal [painted] * 3, vb_levels { PokeAccess.logro_indexed_text(hidden) }, "placeholder in #{copy.keys.first}"
        assert_equal painted, PokeAccess::Info.info_text, "the info key, placeholder in #{copy.keys.first}"
      end
    end
  end

  test "says a hidden achievement with no description by its placeholder alone" do
    with_consts(Object, :NOMBREOCULTO => "????") do
      assert_equal "????", PokeAccess.logro_indexed_text(Achievement.new("????", 1, nil))
    end
  end

  test "reads a locked achievement that keeps its real name as locked" do
    with_consts(Object, :NOMBREOCULTO => "????") do
      assert_equal "Primera medalla, #{t(:ach_locked)}. Consigue tu primera medalla.",
                   PokeAccess.logro_indexed_text(Achievement.new("Primera medalla", 1, "Consigue tu primera medalla."))
    end
  end

  test "says an achievement earned with its reward waiting as earned, and from medium how to collect it" do
    head = "Pescador, #{t(:ach_earned)}"
    with_consts(Object, :Logros => logros_module(:LOGRO_ACTIVO => 2)) do
      assert_equal [head, "#{head}. #{t(:ach_reward)}", "#{head}. Pesca 10. #{t(:ach_reward)}"],
                   vb_levels { PokeAccess.logro_indexed_text(Achievement.new("Pescador", 2, "Pesca 10.")) }
    end
  end

  test "says the reward line the game paints, with its key, where the game has a key reader" do
    reader = Module.new
    reader.define_singleton_method(:key_name) { |_button| "C" }
    with_consts(Object, :Logros => logros_module(:LOGRO_ACTIVO => 2), :KeybindingReader => reader) do
      assert_equal "Pescador, #{t(:ach_earned)}. Pesca 10. [C]: Obtener recompensa",
                   PokeAccess.logro_indexed_text(Achievement.new("Pescador", 2, "Pesca 10."))
    end
  end

  test "reads the other states as they are where a copy has the reward state" do
    with_consts(Object, :Logros => logros_module(:LOGRO_ACTIVO => 2)) do
      assert_equal ["Pescador, #{t(:ach_done)}. Pesca 10.", "Pescador, #{t(:ach_locked)}. Pesca 10."],
                   [3, 1].map { |status| PokeAccess.logro_indexed_text(Achievement.new("Pescador", status, "Pesca 10.")) }
    end
  end

  test "reads the middle state as pending in a copy whose top-level LOGRO_ACTIVO means not yet completed" do
    with_consts(Object, :LOGRO_OCULTO => 1, :LOGRO_ACTIVO => 2, :LOGRO_COMPLETADO => 3) do
      assert_equal "Pescador, #{t(:ach_pending)}. Pesca 10.",
                   PokeAccess.logro_indexed_text(Achievement.new("Pescador", 2, "Pesca 10."))
    end
  end

  test "reads the indexed screen's focused entry once, and again as its cursor moves" do
    scene = achievements_scene
    on_achievements(scene) do
      2.times { PokeAccess::LogrosIndexed.poll }
      scene.instance_variable_set(:@indexSel, 1)
      PokeAccess::LogrosIndexed.poll
    end
    assert_equal [[pending_line, true], ["Campeon, #{t(:ach_done)}. Vence a la Liga.", true]], SpeakCapture.log
  end

  test "reads the indexed screen's focused entry again when its state changes" do
    scene = achievements_scene
    on_achievements(scene) do
      PokeAccess::LogrosIndexed.poll
      scene.instance_variable_get(:@logros)[0].status = 3
      PokeAccess::LogrosIndexed.poll
    end
    assert_equal [pending_line, "Pescador, #{t(:ach_done)}. Pesca 10."], SpeakCapture.lines
  end

  test "reads a scrolled achievement description again only while descriptions are said" do
    { :full => [pending_line, pending_line], :medium => ["Pescador, #{t(:ach_pending)}"] }.each do |level, want|
      PokeAccess::Config.verbosity = level
      SpeakCapture.clear
      scene = achievements_scene
      on_achievements(scene) do
        PokeAccess::LogrosIndexed.poll
        scene.instance_variable_set(:@descOffset, 1)
        PokeAccess::LogrosIndexed.poll
      end
      assert_equal want, SpeakCapture.lines, "at #{level}"
    end
  end

  test "reads nothing on the indexed screen before its cursor is placed, or past its list" do
    [nil, 2].each do |cursor|
      scene = achievements_scene
      scene.instance_variable_set(:@indexSel, cursor)
      on_achievements(scene) { PokeAccess::LogrosIndexed.poll }
    end
    assert_nothing_spoken
  end

  test "reads the indexed screen's focused entry anew each time it opens" do
    scene = achievements_scene
    2.times { on_achievements(scene) { PokeAccess::LogrosIndexed.poll } }
    assert_equal [pending_line, pending_line], SpeakCapture.lines
  end

  test "stands the indexed screen's reader down once the screen closes" do
    on_achievements(achievements_scene) { assert PokeAccess::LogrosIndexed.watching?, "while it runs" }
    PokeAccess::LogrosIndexed.poll
    assert_equal [false, []], [PokeAccess::LogrosIndexed.watching?, SpeakCapture.log], "after it closes"
  end

  test "shows the achievements poll idle in the performance diagnostic with no screen open" do
    assert_includes diag_lines, "logros_poll: scene=idle"
  end

  test "benches an open achievements screen without reading it or changing what it reads next" do
    on_achievements(achievements_scene) do
      assert_includes diag_lines, "logros_poll: scene=ACTIVE"
      assert_nothing_spoken "the bench reads nothing"
      PokeAccess::LogrosIndexed.poll
    end
    assert_equal [pending_line], SpeakCapture.lines, "the screen's next poll still reads its entry"
  end

  test "times the achievements poll's bench in milliseconds" do
    with_clock(2.0, 2.25) { assert_includes diag_lines, "logros_poll: 5000x poll = 250.00ms (idle should be ~0)" }
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # The suffix the locator adds to a berry plant whose event holds data.
  def suffix(data)
    PokeAccess::Berry.state_suffix(PlantEvent.new(data))
  end

  # A gen-3 soil as the gen-6 engine keeps it in the plant event's variable: six slots, the fifth unused.
  def gen3_soil(stage, berry, water = 0)
    [stage, berry, false, 1, water, 0]
  end

  # A gen-4 soil: eight slots, its moisture (0 to 100) in the fifth.
  def gen4_soil(stage, berry, water)
    [stage, berry, 0, 0, water, 0, 0, 0]
  end

  # Runs the block with the game naming the items as names does (nil for the rest), as its data provider would.
  def with_item_names(names)
    provider = Object.new
    provider.define_singleton_method(:item_name) { |id| names[id] }
    Harness.with_provider(provider) { yield }
  end

  # The phone list's row i, its contacts named Joven Pepe and Dama Ana.
  def phone_row(i)
    PokeAccess::Menus.focused_text(Window_PhoneList.new(["Joven Pepe", "Dama Ana"], i))
  end

  # Runs the block with the phone open on a scene holding ivars, as the phone's hooks hold it while it runs.
  def on_phone(ivars)
    PokeAccess::Phone.watch(World.stub_scene(ivars))
    yield
  ensure
    PokeAccess::Phone.unwatch
  end

  # A tip-card screen showing card index of tips.
  def tip_scene(tips, index)
    World.stub_scene(:@tips => tips, :@index => index)
  end

  # The block's value with the tip-card addon's tables (its cards, its groups and any other settings) in the game's
  # Settings module, made for the block where the game has none.
  def with_tip_cards(cards, groups = {}, settings = {})
    made = !Object.const_defined?(:Settings, false)
    Object.const_set(:Settings, Module.new) if made
    with_consts(::Settings, { :TIP_CARDS_CONFIGURATION => cards, :TIP_CARDS_GROUPS => groups }.merge(settings)) { yield }
  ensure
    Object.send(:remove_const, :Settings) if made
  end

  # How many bodies evaluating the group-list wrap of plugins/tip_cards.rb adds to pbShowCommands, evaluated under a
  # name of its own so the file's coverage is kept; the bodies it added are taken away after.
  def group_list_wraps_added
    bodies = (PokeAccess::Hooks.fn_bodies["pbShowCommands|around"] ||= [])
    before = bodies.length
    eval(Harness.source(TIP_CARDS)[/^unless PokeAccess\.const_at.*?^end$/m], TOPLEVEL_BINDING, "tip_cards_group_list")
    bodies.length - before
  ensure
    bodies.slice!(before..-1) if bodies && before
  end

  # Runs the block with the player's C button moved to K, the letters painted as RGSS names them.
  def with_c_on_k
    was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
    PokeAccess::Config.rebinds = { :c => 0x4B }
    PokeAccess::Config.key_hint_letters = PokeAccess::KeyHints::RGSS_LETTERS
    yield
  ensure
    PokeAccess::Config.rebinds = was[0]
    PokeAccess::Config.key_hint_letters = was[1]
  end

  # The block's value with consts set on owner, each put back as it was after (removed where there was none).
  def with_consts(owner, consts)
    saved = consts.keys.map { |k| [k, owner.const_defined?(k, false) ? [owner.const_get(k, false)] : nil] }
    consts.each do |k, v|
      owner.send(:remove_const, k) if owner.const_defined?(k, false)
      owner.const_set(k, v)
    end
    yield
  ensure
    (saved || []).each do |k, old|
      owner.send(:remove_const, k) if owner.const_defined?(k, false)
      owner.const_set(k, old[0]) if old
    end
  end

  # Runs the block with the mod's clock answering times in turn, then the last one; the real clock put back after.
  def with_clock(*times)
    real = PokeAccess.method(:clock)
    queue = times.dup
    PokeAccess.define_singleton_method(:clock) { queue.length > 1 ? queue.shift : queue.first }
    yield
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # A module standing in for a copy's Logros, holding consts.
  def logros_module(consts)
    m = Module.new
    consts.each { |k, v| m.const_set(k, v) }
    m
  end

  # The indexed achievements screen, its cursor on the first of two entries: a pending one and a completed one.
  def achievements_scene
    World.stub_scene(:@indexSel => 0, :@descOffset => 0,
                     :@logros => [Achievement.new("Pescador", 2, "Pesca 10."), Achievement.new("Campeon", 3, "Vence a la Liga.")])
  end

  # What the indexed screen says of its first entry, at full.
  def pending_line
    "Pescador, #{t(:ach_pending)}. Pesca 10."
  end

  # Runs the block with the indexed achievements screen open on scene, as its pbUpdate loop holds it.
  def on_achievements(scene)
    PokeAccess::LogrosIndexed.watch(scene)
    yield
  ensure
    PokeAccess::LogrosIndexed.unwatch
  end

  # The lines the achievements poll's performance diagnostic writes.
  def diag_lines
    PokeAccess::Keys.diag_build([:logros_poll]).split("\n")
  end
end
