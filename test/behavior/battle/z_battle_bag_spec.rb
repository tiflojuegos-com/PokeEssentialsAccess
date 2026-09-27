# Pokemon Z's battle bag (NewBattleBag): a pocket's items under its name and page, and the use/don't-use confirmation
# with the item's description and the box focused, by the label painted on it. Driven through the profile's hooks on
# a stand-in shaped as Z's own screen, games/pokemon_z/battle_bag.rb evaluated once more over it.
module ZBagSpec
  Rect = Struct.new(:x)
  Sprite = Struct.new(:bitmap, :src_rect)

  def self.sprite
    Sprite.new(Object.new, Rect.new(0))
  end
end

# Z's 232 screen: update leaves the state its ivars hold; useItem? paints its two captions on two new overlays, moves
# the selection frame's source x one box per frame, repaints the last-used button and answers whether the first box
# was taken, dropping the item otherwise.
class NewBattleBag
  attr_accessor :frames

  def initialize(state = {})
    state.each { |k, v| instance_variable_set(k, v) }
    @sprites = { "sel" => ZBagSpec.sprite }
  end

  def update
    :updated
  end

  def useItem?
    @sprites["overlay2_1"] = ZBagSpec.sprite
    @sprites["overlay2_2"] = ZBagSpec.sprite
    (@captions || ["USAR", "NO USAR"]).each_with_index do |text, i|
      pbDrawOutlineText(@sprites["overlay2_#{i + 1}"].bitmap, 0, 186 + 72 * i, 512, 384, text, nil, nil, 1)
    end
    index = 0
    (@frames || []).each do |box|
      index = box
      @sprites["sel"].src_rect.x = 466 * (index + 2)
      PokeAccess::Keys.run_frame_pollers
    end
    pbDrawOutlineText(Object.new, 0, 16, 356, 60, "Último objeto usado", nil, nil, 1)
    @ret = nil if index > 0
    index == 0
  end
end

verbose = $VERBOSE
begin
  $VERBOSE = nil
  load File.join(Harness::ROOT, "games", "pokemon_z", "battle_bag.rb")
ensure
  $VERBOSE = verbose
end

# Each update of the item list says the focused item, headed by the pocket's name and page only on another page.
Suite.define("z battle bag: a pocket's items come under its name and page, said again only on another page") do
  t = PokeAccess::I18n
  bag = NewBattleBag.new(:@selPocket => 2, :@pname => "Medicinas", :@pages => 2, :@item => 0, :@back => false,
                         :@index => 0, :@pocket => [[1, 3], [25, 2], [3, 1], [4, 1], [5, 1], [6, 1], [7, 1]])
  SpeakCapture.clear
  eq "the update keeps its own value", bag.update, :updated
  eq "entering the pocket: its name and page, then the item", SpeakCapture.lines,
     ["Medicinas, #{t.t(:zbb_page, :n => 1, :tot => 2)}. Pocion, 3"]

  SpeakCapture.clear
  bag.instance_variable_set(:@item, 1)
  bag.update
  eq "the next item on the same page: the item alone", SpeakCapture.lines, ["Repel, 2"]

  SpeakCapture.clear
  bag.instance_variable_set(:@item, 6)
  bag.update
  eq "crossing to the second page says it", SpeakCapture.lines,
     ["Medicinas, #{t.t(:zbb_page, :n => 2, :tot => 2)}. Item7, 1"]

  SpeakCapture.clear
  bag.instance_variable_set(:@back, true)
  bag.update
  eq "the back button, with no page", SpeakCapture.lines, [t.t(:bb_back)]

  bag.instance_variable_set(:@back, false)
  bag.instance_variable_set(:@selPocket, 0)
  bag.update
  bag.instance_variable_set(:@selPocket, 2)
  bag.instance_variable_set(:@item, 0)
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    bag.update
    eq "back in the pocket after the pocket buttons: the name again, and brief leaves the page out",
       SpeakCapture.lines, ["Medicinas. Pocion, 3"]
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

# useItem? says the item's description, then each frame the box its selection frame sits on, by the caption painted
# on that box's overlay; nothing once it returns, and the mod's own word for a box whose caption was never caught.
Suite.define("z battle bag: the confirmation says the description, then the box focused by the label painted on it") do
  made = !MessageTypes.const_defined?(:ItemDescriptions)
  MessageTypes.const_set(:ItemDescriptions, 4) if made
  begin
    bag = NewBattleBag.new(:@ret => 1)
    bag.frames = [0, 0, 1, 0]
    SpeakCapture.clear
    eq "the game's answer comes back through the hook", bag.useItem?, true
    eq "the description queued after the item's name, the first box queued too, the moves interrupting",
       SpeakCapture.log, [["msg1", false], ["USAR", false], ["NO USAR", true], ["USAR", true]]

    SpeakCapture.clear
    PokeAccess::Keys.run_frame_pollers
    silent "once it closes, the frames say nothing"

    bare = NewBattleBag.new(:@ret => 1, :@captions => [])
    bare.frames = [1]
    SpeakCapture.clear
    eq "declining answers no", bare.useItem?, false
    eq "with no label caught, the mod's word for the box", SpeakCapture.lines,
       ["msg1", PokeAccess::I18n.t(:ura_bag_dont_use)]
  ensure
    MessageTypes.send(:remove_const, :ItemDescriptions) if made && MessageTypes.const_defined?(:ItemDescriptions)
  end
end
