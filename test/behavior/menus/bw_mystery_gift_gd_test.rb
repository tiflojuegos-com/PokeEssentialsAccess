# BW Mystery Gift (plugins/bw_mystery_gift.rb): the menu, what a Wonder Card's icon shows in the album and the viewer,
# the internet download's carousel of gift names and the gift a typed password matches.

# The plugin's menu: sprite buttons over @commands, the cursor in @index, pbUpdate run every frame.
class PokemonMGift_Scene
  def initialize(commands); @commands = commands; @index = 0; end
  def pbUpdate; end
end

# The card album, a paged grid: the cursor in @selected_card, moved by updateCursorPosition.
class WonderCardAlbumScene
  CARDS_PER_PAGE = 3
  def initialize(cards, selected); @cards = cards; @selected_card = selected; end
  def updateCursorPosition; end
end

# The card viewer: the card at @index of the cards pbStartScene is given, painted once.
class WonderCardScene
  def initialize(index); @index = index; end
  def pbStartScene(cards); @cards = cards; end
end

# The plugin's two downloads, reduced to the calls the reader hooks: the internet one decrypts the pending gifts, then
# paints the focused gift's name on each frame of its carousel; the password one asks for the password, then decrypts.
module MysteryGiftCustom
  module_function

  def pbDownloadMysteryGift_Internet(gifts, frames)
    pbMysteryGiftDecrypt(gifts)
    frames.each { |name| pbDrawTextPositions(nil, [[name, 0, 14]]) }
  end

  def pbDownloadMysteryGift_Password(gifts, typed)
    pbEnterPasswordFreeText(typed)
    pbMysteryGiftDecrypt(gifts)
  end
end

# The game's password prompt, answering what the player types, and its decrypt, answering the gift list.
def pbEnterPasswordFreeText(typed); typed; end
def pbMysteryGiftDecrypt(gifts); gifts; end

gift_path = File.join(Harness::ROOT, "plugins", "bw_mystery_gift.rb")
gift_src = Harness.source(gift_path)
gift_hooks = gift_src.index('PokeAccess::Hooks.after_hook("PokemonMGift_Scene"')
eval(gift_src[gift_hooks..-1], TOPLEVEL_BINDING, gift_path, gift_src[0, gift_hooks].count("\n") + 1)

class BwMysteryGiftGdTest < PokeAccessTest
  # A Pokemon gift's data, as the plugin keeps it.
  Mon = Struct.new(:species)

  # A Wonder Card as the plugin's WonderCard keeps it: gift_type 0 for a Pokemon, else the count of its item, which
  # the card keeps only for a gift of one.
  Card = Struct.new(:title, :gift_type, :pokemon_data, :item, :description, :date_received, :claimed) do
    def claimed?; claimed; end
  end

  # The decrypted gifts: [id, type, data, name, ...the plugin's fields..., password].
  GIFTS = [[7, 0, Mon.new(:MEW), "Mew Gift", "", nil, "MEWPASS"], [8, 1, :MASTERBALL, "Ball Gift", "", nil, "BALL"],
           [9, 1, "RARECANDY x3", "Candy Gift", "", nil, "CANDY"], [10, 1, :POTION, "Open Gift", "", nil, ""]]

  # The internet download's pending gifts: [id, type, data, the name its carousel paints].
  PENDING = [[7, 0, Mon.new(:MEW), "Mew"], [8, 1, :MASTERBALL, "Master Ball"]]

  test "the menu says each entry the cursor moves to, whatever shape the game keeps it in" do
    scene = PokemonMGift_Scene.new([{ "name" => "Recibir regalo" }, { :name => "Ver tarjetas" },
                                    [:download, "Por Internet"], "Salir"])
    said = (0..3).map do |i|
      SpeakCapture.clear
      scene.instance_variable_set(:@index, i)
      scene.pbUpdate
      SpeakCapture.log.dup
    end
    assert_equal ["Recibir regalo", "Ver tarjetas", "Por Internet", "Salir"].map { |label| [[label, true]] }, said
  end

  test "a Pokemon card shows its species, kept whole or bare" do
    [Mon.new(:MEW), :MEW].each do |data|
      card = Card.new("Mew Gift", 0, data)
      assert_equal "SpeciesMEW", PokeAccess::BWMysteryGift.contents(card), "for #{data.inspect}"
    end
  end

  test "an item card shows its item, kept by id, by name or as its data" do
    [:MASTERBALL, "MASTERBALL", GameData::Item.get(:MASTERBALL)].each do |item|
      card = item_card("Ball Gift", item)
      assert_equal "ItemMASTERBALL", PokeAccess::BWMysteryGift.contents(card), "for #{item.inspect}"
    end
  end

  test "a card whose icon shows nothing names nothing" do
    { "a gift of several items, which keeps no item" => item_card("Candy Gift", :RARECANDY, 3),
      "a Pokemon card without its Pokemon" => Card.new("Odd Gift", 0, nil, nil),
      "a card the data cannot read" => Object.new }.each do |what, card|
      assert_nil PokeAccess::BWMysteryGift.contents(card), what
    end
    nameless_data(:item_name, "") do
      assert_nil PokeAccess::BWMysteryGift.contents(item_card("Ball Gift", :MASTERBALL)), "an item the data names blank"
    end
  end

  test "beside a title that does not name them, a card's contents are named" do
    card = item_card("Ball Gift", :MASTERBALL)
    assert_equal "ItemMASTERBALL", PokeAccess::BWMysteryGift.contents_beside("Ball Gift", card)
  end

  test "beside a title that names them, in any case, a card's contents are left out" do
    ["Mega ItemMasterBall", "ITEMMASTERBALL x1"].each do |title|
      assert_nil PokeAccess::BWMysteryGift.contents_beside(title, item_card(title, :MASTERBALL)), "for #{title.inspect}"
    end
  end

  test "the viewer says the card's title, what it shows, that it is not received yet and its description, cutting in" do
    WonderCardScene.new(0).pbStartScene([item_card("Ball Gift", :MASTERBALL)])
    assert_equal [["Ball Gift. ItemMASTERBALL. #{t(:mgift_unclaimed)}. A gift.", true]], SpeakCapture.log
  end

  test "the viewer says a received card was received, and when" do
    card = item_card("Ball Gift", :MASTERBALL)
    card.claimed = true
    card.date_received = Time.new(2024, 3, 5)
    PokeAccess::BWMysteryGift.viewer(viewer_on(card))
    said = "Ball Gift. ItemMASTERBALL. #{t(:mgift_claimed)}. #{t(:mgift_date, :d => '05 Mar 2024')}. A gift."
    assert_equal [[said, true]], SpeakCapture.log
  end

  test "the viewer leaves out what the title already names, and a blank description" do
    card = item_card("Mega ItemMASTERBALL", :MASTERBALL)
    card.description = ""
    PokeAccess::BWMysteryGift.viewer(viewer_on(card))
    assert_equal [["Mega ItemMASTERBALL. #{t(:mgift_unclaimed)}", true]], SpeakCapture.log
  end

  test "the viewer says nothing without a card at its index" do
    [WonderCardScene.new(1), WonderCardScene.new(nil)].each do |scene|
      scene.pbStartScene([item_card("Ball Gift", :MASTERBALL)])
    end
    PokeAccess::BWMysteryGift.viewer(WonderCardScene.new(0))
    assert_nothing_spoken
  end

  test "the album says the focused card's title, what it shows, its place and that it is not received, cutting in" do
    album([item_card("Ball Gift", :MASTERBALL), pokemon_card("Mew Gift")], 1).updateCursorPosition
    assert_equal [["#{entry('Mew Gift, SpeciesMEW', 2, 2)}, #{t(:mgift_unclaimed)}", true]], SpeakCapture.log
  end

  test "the album says the card the cursor stays on once" do
    scene = album([pokemon_card("Mew Gift")], 0)
    scene.updateCursorPosition
    SpeakCapture.clear
    scene.updateCursorPosition
    assert_nothing_spoken
  end

  test "the album says a card again once it is received" do
    card = pokemon_card("Mew Gift")
    scene = album([card], 0)
    scene.updateCursorPosition
    SpeakCapture.clear
    card.claimed = true
    scene.updateCursorPosition
    assert_equal [["#{entry('Mew Gift, SpeciesMEW', 1, 1)}, #{t(:mgift_claimed)}", true]], SpeakCapture.log
  end

  test "a deletion that shifts the next card under the cursor says that card" do
    scene = album([pokemon_card("Mew Gift"), item_card("Ball Gift", :MASTERBALL)], 0)
    scene.updateCursorPosition
    SpeakCapture.clear
    scene.instance_variable_set(:@cards, [item_card("Ball Gift", :MASTERBALL)])
    scene.updateCursorPosition
    assert_equal [["#{entry('Ball Gift, ItemMASTERBALL', 1, 1)}, #{t(:mgift_unclaimed)}", true]], SpeakCapture.log
  end

  test "a cursor left past the last card says the last card" do
    [2, 5].each do |selected|
      SpeakCapture.clear
      album([item_card("Ball Gift", :MASTERBALL), pokemon_card("Mew Gift")], selected).updateCursorPosition
      assert_equal [["#{entry('Mew Gift, SpeciesMEW', 2, 2)}, #{t(:mgift_unclaimed)}", true]], SpeakCapture.log,
                   "selected #{selected}"
    end
  end

  test "the album says nothing with no card to focus or a card without a title" do
    [album([], 0), album(nil, 0), album([pokemon_card("Mew Gift")], -1), album([pokemon_card("Mew Gift")], nil),
     album([pokemon_card("")], 0), album([nil], 0)].each(&:updateCursorPosition)
    assert_nothing_spoken
  end

  test "the album leaves out a received state the card does not keep, and adds the date it was received" do
    card = item_card("Ball Gift", :MASTERBALL)
    card.claimed = nil
    card.date_received = Time.new(2024, 3, 5)
    album([card], 0).updateCursorPosition
    assert_equal [["#{entry('Ball Gift, ItemMASTERBALL', 1, 1)}, 05 Mar 2024", true]], SpeakCapture.log
  end

  test "a card whose title names what it shows is said by its title alone" do
    album([item_card("Mega ItemMASTERBALL", :MASTERBALL)], 0).updateCursorPosition
    assert_equal [["#{entry('Mega ItemMASTERBALL', 1, 1)}, #{t(:mgift_unclaimed)}", true]], SpeakCapture.log
  end

  test "on an album of several pages the card's page follows, from the medium verbosity" do
    cards = %w[Uno Dos Tres Cuatro].map { |title| item_card(title, :POTION, 2) }
    said = vb_levels do
      SpeakCapture.clear
      album(cards, 3).updateCursorPosition
      SpeakCapture.lines
    end
    unclaimed = t(:mgift_unclaimed)
    paged = "#{entry('Cuatro', 4, 4)}, #{unclaimed}. #{t(:mgift_page, :n => 2, :tot => 2)}"
    assert_equal [["Cuatro, #{unclaimed}"], [paged], [paged]], said
  end

  test "the page counts the album's own page size" do
    cards = %w[Uno Dos].map { |title| item_card(title, :POTION, 2) }
    { 1 => "#{entry('Dos', 2, 2)}, #{t(:mgift_unclaimed)}. #{t(:mgift_page, :n => 2, :tot => 2)}",
      0 => "#{entry('Dos', 2, 2)}, #{t(:mgift_unclaimed)}" }.each do |per, line|
      SpeakCapture.clear
      with_cards_per_page(per) { album(cards, 1).updateCursorPosition }
      assert_equal [[line, true]], SpeakCapture.log, "#{per} cards a page"
    end
  end

  test "the carousel says the first gift and what it is, queued" do
    internet_download do
      PokeAccess::BWMysteryGift.painted([["Mew", 0, 14]])
      assert_equal [["Mew, #{t(:mgift_kind_pokemon)}", false]], SpeakCapture.log
    end
  end

  test "the carousel says a gift repainted on every frame once" do
    internet_download do
      PokeAccess::BWMysteryGift.painted([["Mew", 0, 14]])
      SpeakCapture.clear
      PokeAccess::BWMysteryGift.painted([["Mew", 0, 14]])
      assert_nothing_spoken
    end
  end

  test "the carousel cuts in with each gift it moves to" do
    internet_download do
      PokeAccess::BWMysteryGift.painted([["Mew", 0, 14]])
      SpeakCapture.clear
      PokeAccess::BWMysteryGift.painted([["Master Ball", 0, 14]])
      assert_equal [["Master Ball, #{t(:mgift_kind_item)}", true]], SpeakCapture.log
    end
  end

  test "a paint that is no pending gift is not the carousel's" do
    internet_download do
      [[["Money", 0, 0]], [], "Mew", nil, ["Mew"]].each { |rows| PokeAccess::BWMysteryGift.painted(rows) }
      assert_nothing_spoken
    end
  end

  test "with no download running, or the password one, a gift's name painted is not read" do
    PokeAccess::BWMysteryGift.painted([["Mew", 0, 14]])
    password_download(nil) do
      PokeAccess::BWMysteryGift.note_gifts(GIFTS)
      PokeAccess::BWMysteryGift.painted([["Mew Gift", 0, 14]])
    end
    assert_nothing_spoken
  end

  test "a decrypt that gives no list leaves the carousel without gifts" do
    PokeAccess::BWMysteryGift.download(:internet)
    PokeAccess::BWMysteryGift.note_gifts(nil)
    PokeAccess::BWMysteryGift.painted([["Mew", 0, 14]])
    assert_nothing_spoken
  ensure
    PokeAccess::BWMysteryGift.download(nil)
  end

  test "the internet download, as the game runs it, says the gifts its carousel moves to and nothing after" do
    MysteryGiftCustom.pbDownloadMysteryGift_Internet(PENDING, ["Mew", "Mew", "Master Ball"])
    pbDrawTextPositions(nil, [["Mew", 0, 14]])
    assert_equal [["Mew, #{t(:mgift_kind_pokemon)}", false], ["Master Ball, #{t(:mgift_kind_item)}", true]],
                 SpeakCapture.log
  end

  test "the password download, as the game runs it, says the gift the password matches" do
    MysteryGiftCustom.pbDownloadMysteryGift_Password(GIFTS, "MEWPASS")
    assert_equal [["SpeciesMEW, #{t(:mgift_kind_pokemon)}", false]], SpeakCapture.log
  end

  test "a password matching an item gift says the item its sprite shows" do
    { "BALL" => "ItemMASTERBALL", "CANDY" => "ItemRARECANDY" }.each do |password, item|
      SpeakCapture.clear
      password_download(password) { PokeAccess::BWMysteryGift.note_gifts(GIFTS) }
      assert_equal [["#{item}, #{t(:mgift_kind_item)}", false]], SpeakCapture.log, "password #{password}"
    end
  end

  test "a gift already received, or a password matching nothing, is left to the game's own message" do
    with_received([8]) do
      %w[BALL NOPE].each { |password| password_download(password) { PokeAccess::BWMysteryGift.note_gifts(GIFTS) } }
    end
    assert_nothing_spoken
  end

  test "a matching gift is said when the player keeps no record of the gifts received" do
    password_download("BALL") { PokeAccess::BWMysteryGift.note_gifts(GIFTS) }
    assert_equal [["ItemMASTERBALL, #{t(:mgift_kind_item)}", false]], SpeakCapture.log
  end

  test "with no password typed, or a blank one, nothing is said, not even a gift without one" do
    [nil, ""].each { |password| password_download(password) { PokeAccess::BWMysteryGift.note_gifts(GIFTS) } }
    assert_nothing_spoken
  end

  test "a gift the data cannot name is said by the gift's own name" do
    [nil, ""].each do |blank|
      SpeakCapture.clear
      nameless_data(:species_name, blank) do
        password_download("MEWPASS") { PokeAccess::BWMysteryGift.note_gifts(GIFTS) }
      end
      assert_equal [["Mew Gift, #{t(:mgift_kind_pokemon)}", false]], SpeakCapture.log, "named #{blank.inspect}"
    end
  end

  test "the internet download takes no password and names its gifts on its carousel only" do
    internet_download do
      PokeAccess::BWMysteryGift.note_password("MEWPASS")
      PokeAccess::BWMysteryGift.note_gifts(GIFTS)
      assert_nothing_spoken
    end
  end

  test "gifts decrypted with no download running are not said" do
    PokeAccess::BWMysteryGift.note_password("MEWPASS")
    PokeAccess::BWMysteryGift.note_gifts(GIFTS)
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A row with its place, as the full verbosity says it.
  def entry(row, n, tot)
    t(:list_entry, :name => row, :n => n, :tot => tot)
  end

  # A Pokemon gift's card, not received yet.
  def pokemon_card(title)
    Card.new(title, 0, Mon.new(:MEW), nil, "A gift.", nil, false)
  end

  # An item gift's card of count items, not received yet; the card keeps the item only for a gift of one.
  def item_card(title, item, count = 1)
    Card.new(title, count, nil, count == 1 ? item : nil, "A gift.", nil, false)
  end

  # The album on cards, its cursor on selected.
  def album(cards, selected)
    WonderCardAlbumScene.new(cards, selected)
  end

  # The viewer, opened on card.
  def viewer_on(card)
    scene = WonderCardScene.new(0)
    scene.instance_variable_set(:@cards, [card])
    scene
  end

  # Runs the block inside the internet download, its pending gifts noted.
  def internet_download
    PokeAccess::BWMysteryGift.download(:internet)
    PokeAccess::BWMysteryGift.note_gifts(PENDING)
    yield
  ensure
    PokeAccess::BWMysteryGift.download(nil)
  end

  # Runs the block inside the password download, password typed (none for nil).
  def password_download(password)
    PokeAccess::BWMysteryGift.download(:password)
    PokeAccess::BWMysteryGift.note_password(password) unless password.nil?
    yield
  ensure
    PokeAccess::BWMysteryGift.download(nil)
  end

  # Runs the block with a player who has received the gifts of the given ids.
  def with_received(ids)
    had = $player
    $player = Struct.new(:mystery_gifts).new(ids.map { |id| [id] })
    yield
  ensure
    $player = had
  end

  # Runs the block with the data naming every id by method as blank.
  def nameless_data(method, blank)
    provider = Object.new
    provider.define_singleton_method(method) { |_id| blank }
    Harness.with_provider(provider, 30) { yield }
  end

  # Runs the block with the album's page size set to per cards.
  def with_cards_per_page(per)
    was = WonderCardAlbumScene::CARDS_PER_PAGE
    WonderCardAlbumScene.send(:remove_const, :CARDS_PER_PAGE)
    WonderCardAlbumScene.const_set(:CARDS_PER_PAGE, per)
    yield
  ensure
    WonderCardAlbumScene.send(:remove_const, :CARDS_PER_PAGE)
    WonderCardAlbumScene.const_set(:CARDS_PER_PAGE, was)
  end
end
