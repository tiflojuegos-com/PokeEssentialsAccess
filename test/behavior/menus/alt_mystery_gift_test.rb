# Clara's Alternative Mystery Gifts (plugins/alt_mystery_gift.rb): the menu and the card album are read by their cursor,
# the gift list, whose cursor is a local of its method, by a mirror of its arrows, the album's own command list by the
# question it is asked under, and the two card screens by what they paint.

# Keys held for a block, as the game's Input.trigger? sees them.
module AltMysteryGiftKeys
  def self.pressing(*keys)
    was = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |key| keys.include?(key) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, was)
  end
end

# A gift of the list: only its title is read.
AltMysteryGiftCard = Struct.new(:title)

# The menu and the gift list, each loop cut down to the frames a test gives it: the menu visits the entries it is told
# to (a symbol is a submenu opened from it), the list runs one frame per set of keys.
class MysteryGiftScene
  attr_accessor :visits, :presses
  attr_reader :nesting_seen

  def initialize
    @text = ["RECIBIR VÍA INTERNET", "RECIBIR VÍA CÓDIGO", "VER TARJETAS", "SALIR"]
    @sel = 0
    @visits = [0]
    @presses = []
  end

  def pbMGCommands
    @nesting_seen = PokeAccess::MenuReturn.instance_variable_get(:@depth)
    @visits.each do |visit|
      if visit == :receive
        pbReceiveGift(:online)
      else
        @sel = visit
      end
      PokeAccess::Frame.run_pollers
    end
    :menu_closed
  end

  def pbReceiveGift(_method)
    Kernel.pbMessage("Buscando regalos.")
    PokeAccess::Frame.run_pollers
    Kernel.pbMessage("Fin.")
    :received
  end

  def pbChooseGiftFromList(_gifts)
    PokeAccess::Frame.run_pollers
    @presses.each { |keys| AltMysteryGiftKeys.pressing(*keys) { PokeAccess::Frame.run_pollers } }
    :list_closed
  end
end

# The album: pbStartScene paints the overlay, and its loop visits [page, slot] pairs, a :command opening the card
# command and a :delete taking the card under the cursor out of the list.
class CardAlbumScene
  CARDS_PER_PAGE = 4
  OVERLAY = [["ÁLBUM DE TARJETAS", 256, 18, 2], ["SALIR", 424, 320, 2]].freeze
  attr_accessor :visits

  def initialize(cards, painted = true, overlay = OVERLAY)
    @cards = cards
    @sel = 0
    @page = 0
    @maxPages = [(cards.length.to_f / CARDS_PER_PAGE).ceil, 1].max
    @painted = painted
    @overlay = overlay
    @visits = []
  end

  def pbStartScene
    writeOverlayInfo if @painted
  end

  def writeOverlayInfo
    pbDrawTextPositions(nil, @overlay)
    :overlay_drawn
  end

  def pbMainLoop
    @visits.each do |visit|
      if visit == :command
        pbCardCommand
      elsif visit == :delete
        @cards.delete_at(@page * CARDS_PER_PAGE + @sel)
      else
        @page, @sel = visit
      end
      PokeAccess::Frame.run_pollers
    end
    :album_closed
  end

  def pbShowCommandsAlbum(_helptext, _commands); :command_chosen; end

  def pbCardCommand
    PokeAccess::Frame.run_pollers
    :card_command_done
  end
end

# The BW system message the album confirms a deletion through, which the harness has not got.
module Kernel
  def self.pbConfirmMessageSystem(_pos, _black, _message, &block)
    block.call if block
    :confirm_answer
  end
end

# The two card screens, painting their text as the script does.
class WonderCardDetailScene
  def pbSetWonderCardText(_bitmap, data)
    pbDrawTextPositions(nil, [["Tarjeta Misteriosa", 95, 42, 0], [data[:title], 36, 96, 0],
                              ["Fecha recibida", 68, 320, 0], [data[:date], 280, 320, 0]])
    drawTextEx(nil, 36, 144, 400, 6, data[:description], nil, nil)
    :text_set
  end
end

class WonderCardReceivedDetails
  def pbSetWonderCardText(_bitmap, data)
    pbDrawTextPositions(nil, [[data[:title], 64, 40, 0]])
    drawTextEx(nil, 64, 112, 384, 6, data[:description], nil, nil)
    :text_set
  end
end

# The plugin's registrations bound to the stand-ins (the harness's own load of the file ran before they existed),
# less the per-frame poller, which that load registered and which must run once.
amg_src = Harness.source(File.join(Harness::ROOT, "plugins", "alt_mystery_gift.rb"))
eval(amg_src.split(/^end\n/, 2)[1].sub(/^PokeAccess::Frame\.each_pulse.*\n/, ""), TOPLEVEL_BINDING,
     "plugins/alt_mystery_gift.rb")

class AltMysteryGiftTest < PokeAccessTest
  LABELS = { "amg_page" => "página %{n} de %{tot}" }.freeze

  MENU = ["RECIBIR VÍA INTERNET", "RECIBIR VÍA CÓDIGO", "VER TARJETAS", "SALIR"].freeze
  GIFTS = [AltMysteryGiftCard.new("Pikachu Navideño"), AltMysteryGiftCard.new("Poción x5"),
           AltMysteryGiftCard.new("Huevo Misterioso")].freeze
  DATA = { :title => "Pikachu Navideño", :description => "Un Pikachu con gorro.", :date => "25/12/2025" }.freeze

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @added = LABELS.keys.reject { |k| table.key?(k) }
    @added.each { |k| table[k] = LABELS[k] }
    PokeAccess::MenuReturn.reset_nesting
  end

  def teardown
    @added.each { |k| PokeAccess::I18n.table(:es).delete(k) }
    PokeAccess::MenuReturn.reset_nesting
    super
  end

  test "the plugin binds its hooks to the screens" do
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    keys = ["MysteryGiftScene#pbMGCommands", "MysteryGiftScene#pbReceiveGift", "MysteryGiftScene#pbChooseGiftFromList",
            "CardAlbumScene#pbMainLoop", "CardAlbumScene#writeOverlayInfo", "CardAlbumScene#pbShowCommandsAlbum",
            "CardAlbumScene#pbCardCommand", "WonderCardDetailScene#pbSetWonderCardText",
            "WonderCardReceivedDetails#pbSetWonderCardText"]
    assert_equal [], keys.reject { |key| chains.key?(key) }
  end

  test "the menu says the entry its cursor rests on, the first queued, then each move interrupting" do
    scene = MysteryGiftScene.new
    scene.visits = [0, 1, 2, 3, 2]
    scene.pbMGCommands
    assert_equal [[MENU[0], false], [MENU[1], true], [MENU[2], true], [MENU[3], true], [MENU[2], true]],
                 SpeakCapture.log
  end

  test "the menu says nothing while its cursor stays, and hands back its loop's value" do
    scene = MysteryGiftScene.new
    scene.visits = [1, 1, 1]
    assert_equal :menu_closed, scene.pbMGCommands
    assert_equal [[MENU[1], false]], SpeakCapture.log
  end

  test "back from a download the menu says its entry again, and not between the download's own messages" do
    scene = MysteryGiftScene.new
    scene.visits = [1, :receive]
    scene.pbMGCommands
    assert_equal [[MENU[1], false], [MENU[1], true]], SpeakCapture.log
  end

  test "the menu counts its submenus from its own loop, though the screen opened inside a fade" do
    2.times { PokeAccess::MenuReturn.enter! }
    scene = MysteryGiftScene.new
    scene.pbMGCommands
    assert_equal 0, scene.nesting_seen
  end

  test "a menu opened again says its entry again, queued" do
    2.times { MysteryGiftScene.new.pbMGCommands }
    assert_equal [[MENU[0], false], [MENU[0], false]], SpeakCapture.log
  end

  test "the gift list says the gift under the mirrored cursor, the first queued, each move interrupting" do
    scene = MysteryGiftScene.new
    scene.presses = [[Input::DOWN], [Input::DOWN], [Input::UP]]
    scene.pbChooseGiftFromList(GIFTS)
    assert_equal [[row(0), false], [row(1), true], [row(2), true], [row(1), true]], SpeakCapture.log
  end

  test "the mirrored cursor stops at either end of the list as the game's does" do
    scene = MysteryGiftScene.new
    scene.presses = [[Input::UP], [Input::DOWN], [Input::DOWN], [Input::DOWN], [Input::DOWN], [Input::UP]]
    scene.pbChooseGiftFromList(GIFTS)
    assert_equal [row(0), row(1), row(2), row(1)], SpeakCapture.lines
  end

  test "of UP and DOWN pressed together only UP counts, as in the game's chain, and B or C end the loop first" do
    scene = MysteryGiftScene.new
    scene.presses = [[Input::DOWN], [Input::UP, Input::DOWN], [Input::C, Input::DOWN], [Input::B, Input::DOWN]]
    scene.pbChooseGiftFromList(GIFTS)
    assert_equal [row(0), row(1), row(0)], SpeakCapture.lines
  end

  test "a list opened again starts on its first gift, queued" do
    scene = MysteryGiftScene.new
    scene.presses = [[Input::DOWN]]
    2.times { scene.pbChooseGiftFromList(GIFTS) }
    assert_equal [[row(0), false], [row(1), true], [row(0), false], [row(1), true]], SpeakCapture.log
  end

  test "the list hands back its loop's value, and the arrows say nothing outside it" do
    scene = MysteryGiftScene.new
    assert_equal :list_closed, scene.pbChooseGiftFromList(GIFTS)
    SpeakCapture.clear
    AltMysteryGiftKeys.pressing(Input::DOWN) { PokeAccess::Frame.run_pollers }
    assert_nothing_spoken
  end

  test "a list of no gifts, or none given, says nothing" do
    scene = MysteryGiftScene.new
    scene.pbChooseGiftFromList([])
    scene.pbChooseGiftFromList(nil)
    assert_nothing_spoken
  end

  test "the menu has no focus to give without its entries, its cursor or an entry under it" do
    scenes = [Object.new, World.stub_scene(:@sel => 1), World.stub_scene(:@text => MENU),
              World.stub_scene(:@text => MENU, :@sel => 9), World.stub_scene(:@text => MENU, :@sel => "1"),
              World.stub_scene(:@text => "RECIBIR", :@sel => 0)]
    assert_equal [nil] * 6, scenes.map { |scene| PokeAccess::AltMysteryGift.menu_focus(scene) }
    assert_equal [2, "VER TARJETAS"], PokeAccess::AltMysteryGift.menu_focus(World.stub_scene(:@text => MENU, :@sel => 2))
  end

  test "the album has no focus to give without its cards, its slot or its page" do
    scenes = [Object.new, World.stub_scene(:@sel => 0, :@page => 0), World.stub_scene(:@cards => cards(2), :@page => 0),
              World.stub_scene(:@cards => cards(2), :@sel => 0), World.stub_scene(:@cards => "two", :@sel => 0, :@page => 0),
              World.stub_scene(:@cards => cards(2), :@sel => "0", :@page => 0),
              World.stub_scene(:@cards => cards(2), :@sel => 0, :@page => "0")]
    assert_equal [nil] * 7, scenes.map { |scene| PokeAccess::AltMysteryGift.album_focus(scene) }
  end

  test "an album that keeps no count of its pages is taken for one page" do
    scene = World.stub_scene(:@cards => cards(5), :@sel => 0, :@page => 0)
    assert_equal "#{t(:list_entry, :name => 'Tarjeta 1', :n => 1, :tot => 5)}, 25/12/2025",
                 PokeAccess::AltMysteryGift.album_focus(scene)[1].call
  end

  test "a page holds as many cards as the album says, four where it says nothing usable" do
    got = [2, 1, 0, nil, "x", :none].map { |value| with_cards_per_page(value) { PokeAccess::AltMysteryGift.per_page } }
    assert_equal [2, 1, 4, 4, 4, 4], got
  end

  test "the slot under the cursor and the exit button follow the album's own page size" do
    with_cards_per_page(2) do
      scene = CardAlbumScene.new(cards(3))
      scene.visits = [[1, 0], [0, 2]]
      scene.pbMainLoop
    end
    assert_equal ["#{t(:list_entry, :name => 'Tarjeta 3', :n => 3, :tot => 3)}, 25/12/2025, #{t(:amg_page, :n => 2, :tot => 2)}",
                  t(:pc_cancel)], SpeakCapture.lines
  end

  test "a card's date is said as painted: unpadded for a time, as its text for a string, and not at all without" do
    scene = CardAlbumScene.new([["a", { :title => "Uno", :date => "ayer" }], ["b", { :title => "Dos", :date => nil }]])
    scene.visits = [[0, 0], [0, 1]]
    scene.pbMainLoop
    assert_equal [t(:list_entry, :name => "Uno", :n => 1, :tot => 2) + ", ayer",
                  t(:list_entry, :name => "Dos", :n => 2, :tot => 2)], SpeakCapture.lines
  end

  test "an overlay with its title alone leaves the exit button to the mod's own word" do
    scene = CardAlbumScene.new(cards(1), true, [["ÁLBUM DE TARJETAS", 256, 18, 2]])
    scene.pbStartScene
    scene.visits = [[0, 4]]
    scene.pbMainLoop
    assert_equal ["ÁLBUM DE TARJETAS", t(:pc_cancel)], SpeakCapture.lines
  end

  test "a gift with no title is left unsaid, and the cursor still moves on to the next" do
    gifts = [AltMysteryGiftCard.new(nil), AltMysteryGiftCard.new("  "), GIFTS[1]]
    scene = MysteryGiftScene.new
    scene.presses = [[], [Input::DOWN], [Input::DOWN]]
    scene.pbChooseGiftFromList(gifts)
    assert_equal [t(:list_entry, :name => "Poción x5", :n => 3, :tot => 3)], SpeakCapture.lines
  end

  test "the album says its title as it opens, once, queued" do
    scene = CardAlbumScene.new(cards(2))
    scene.pbStartScene
    scene.writeOverlayInfo
    assert_equal [["ÁLBUM DE TARJETAS", false]], SpeakCapture.log
  end

  test "the album says each card its cursor reaches: title, place and date as painted, and the page as it changes" do
    scene = CardAlbumScene.new(cards(5))
    scene.visits = [[0, 0], [0, 1], [1, 0]]
    scene.pbMainLoop
    assert_equal [[card_row(0, 5, 1, "25/12/2025", true), false], [card_row(1, 5, 1, "5/3/2025", false), true],
                  [card_row(4, 5, 2, "25/12/2025", true), true]], SpeakCapture.log
  end

  test "the page is said again when the cursor goes back to a page it left, and not when it stays or returns to its card" do
    scene = CardAlbumScene.new(cards(5))
    scene.visits = [[0, 0], [1, 0], [0, 1], [0, 0], :command]
    scene.pbMainLoop
    assert_equal [card_row(0, 5, 1, "25/12/2025", true), card_row(4, 5, 2, "25/12/2025", true),
                  card_row(1, 5, 1, "5/3/2025", true), card_row(0, 5, 1, "25/12/2025", false),
                  card_row(0, 5, 1, "25/12/2025", false)], SpeakCapture.lines
  end

  test "the album leaves out the page where it has one, and the place and page where positions are not said" do
    one_page = CardAlbumScene.new(cards(3))
    one_page.visits = [[0, 2]]
    one_page.pbMainLoop
    assert_equal ["Tarjeta 3, 3 de 3, 25/12/2025"], SpeakCapture.lines
    said = vb_levels do
      SpeakCapture.clear
      scene = CardAlbumScene.new(cards(5))
      scene.visits = [[1, 0]]
      scene.pbMainLoop
      SpeakCapture.lines.first
    end
    assert_equal ["Tarjeta 5, 25/12/2025", card_row(4, 5, 2, "25/12/2025", true), card_row(4, 5, 2, "25/12/2025", true)],
                 said
  end

  test "the album says a slot past the last card as empty" do
    scene = CardAlbumScene.new(cards(5))
    scene.visits = [[1, 2]]
    scene.pbMainLoop
    assert_equal [t(:row_empty)], SpeakCapture.lines
  end

  test "the exit button is said as the album painted it, or by the mod's cancel where it never did" do
    painted = CardAlbumScene.new(cards(2))
    painted.pbStartScene
    painted.visits = [[0, 4]]
    painted.pbMainLoop
    unpainted = CardAlbumScene.new(cards(2), false)
    unpainted.visits = [[0, 4]]
    unpainted.pbMainLoop
    assert_equal ["ÁLBUM DE TARJETAS", "SALIR", t(:pc_cancel)], SpeakCapture.lines
  end

  test "the album says the card that slid into a slot when the one there is deleted" do
    scene = CardAlbumScene.new(cards(3))
    scene.visits = [[0, 0], :delete]
    scene.pbMainLoop
    assert_equal ["Tarjeta 1, 1 de 3, 25/12/2025", "Tarjeta 2, 1 de 2, 5/3/2025"], SpeakCapture.lines
  end

  test "back from the card command the album says its focused card again, and hands back its loop's value" do
    scene = CardAlbumScene.new(cards(2))
    scene.visits = [[0, 1], :command]
    assert_equal :album_closed, scene.pbMainLoop
    assert_equal [["Tarjeta 2, 2 de 2, 5/3/2025", false], ["Tarjeta 2, 2 de 2, 5/3/2025", true]], SpeakCapture.log
  end

  test "the card command hands back its own value" do
    assert_equal :card_command_done, CardAlbumScene.new(cards(1)).pbCardCommand
  end

  test "the album's command list says the question it is asked under as it opens, queued" do
    ret = CardAlbumScene.new(cards(1)).pbShowCommandsAlbum("¿Qué quieres hacer con esta tarjeta?", ["Ver datos"])
    assert_equal [:command_chosen, [["¿Qué quieres hacer con esta tarjeta?", false]]], [ret, SpeakCapture.log]
  end

  test "the question the album asks before a deletion is read, queued, and the confirmation still answers" do
    asked = "¿Seguro que quieres eliminar esta tarjeta?"
    ret = Kernel.pbConfirmMessageSystem(1, false, asked) { :frame }
    assert_equal [:confirm_answer, [[asked, false]]], [ret, SpeakCapture.log]
  end

  test "the album's overlay paint hands back its value" do
    assert_equal :overlay_drawn, CardAlbumScene.new(cards(1)).writeOverlayInfo
  end

  test "a card opened from the album says its header, title, description and date, interrupting" do
    ret = WonderCardDetailScene.new.pbSetWonderCardText(nil, DATA)
    assert_equal [:text_set, [["Tarjeta Misteriosa. Pikachu Navideño. Un Pikachu con gorro. Fecha recibida 25/12/2025",
                               true]]], [ret, SpeakCapture.log]
  end

  test "the card shown on receiving a gift says its title and description, queued behind the game's messages" do
    ret = WonderCardReceivedDetails.new.pbSetWonderCardText(nil, DATA)
    assert_equal [:text_set, [["Pikachu Navideño. Un Pikachu con gorro.", false]]], [ret, SpeakCapture.log]
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def row(i)
    t(:list_entry, :name => GIFTS[i].title, :n => i + 1, :tot => GIFTS.length)
  end

  def with_cards_per_page(value)
    was = CardAlbumScene.send(:remove_const, :CARDS_PER_PAGE)
    CardAlbumScene.const_set(:CARDS_PER_PAGE, value) unless value == :none
    yield
  ensure
    CardAlbumScene.send(:remove_const, :CARDS_PER_PAGE) if CardAlbumScene.const_defined?(:CARDS_PER_PAGE)
    CardAlbumScene.const_set(:CARDS_PER_PAGE, was)
  end

  def cards(count)
    dates = [Time.local(2025, 12, 25), Time.local(2025, 3, 5)]
    (0...count).map { |i| ["gift#{i}", { :title => "Tarjeta #{i + 1}", :date => dates[i % 2] }] }
  end

  def card_row(idx, total, page, date, noted)
    pages = [(total.to_f / 4).ceil, 1].max
    parts = [t(:list_entry, :name => "Tarjeta #{idx + 1}", :n => idx + 1, :tot => total), date]
    parts.push(t(:amg_page, :n => page, :tot => pages)) if noted && pages > 1
    parts.join(", ")
  end
end
