# BW Mystery Gift: the icons that tell a Wonder Card's contents (the album's species or item, the viewer's sprite),
# the internet download's carousel, which paints only the focused gift's name, and the password download, which shows
# only the sprite of the gift the password matches.

MgSpecMon = Struct.new(:species)

# A Wonder Card as the plugin's WonderCard keeps it: gift_type 0 for a Pokemon, else the item's count, and the item
# itself only for a gift of one.
class MgSpecCard
  attr_accessor :title, :gift_type, :item, :pokemon_data, :description, :date_received
  def initialize(title, gift_type, data)
    @title = title
    @gift_type = gift_type
    @pokemon_data = gift_type == 0 ? data : nil
    @item = gift_type == 1 ? data : nil
    @description = "A gift."
  end
  def claimed?; false; end
end

Suite.define("bw mystery gift: a card says what its icon shows") do
  bw = PokeAccess::BWMysteryGift
  mew = MgSpecCard.new("Mew Gift", 0, MgSpecMon.new(:MEW))
  ball = MgSpecCard.new("Ball Gift", 1, :MASTERBALL)
  candies = MgSpecCard.new("Candy Gift", 3, :RARECANDY)
  eq "a Pokemon card: the species its icon draws", bw.contents(mew), PokeAccess::Data.species_name(:MEW)
  eq "an item card: the item", bw.contents(ball), PokeAccess::Data.item_name(:MASTERBALL)
  eq "a gift of several keeps no item on its card, so its icon shows none and nothing is said", bw.contents(candies),
     nil

  album = World.stub_scene(:@cards => [ball, mew], :@selected_card => 1)
  SpeakCapture.clear
  bw.card(album)
  spoke "the album's focused card names its Pokemon", /#{Regexp.escape(PokeAccess::Data.species_name(:MEW))}/
  viewer = World.stub_scene(:@cards => [ball], :@index => 0)
  SpeakCapture.clear
  bw.viewer(viewer)
  spoke "and the viewer its item", /#{Regexp.escape(PokeAccess::Data.item_name(:MASTERBALL))}/

  item = PokeAccess::Data.item_name(:MASTERBALL)
  named = MgSpecCard.new("Mega #{item}", 1, :MASTERBALL)
  eq "a title that already names its item keeps the item out", bw.contents_beside(named.title, named), nil
  SpeakCapture.clear
  bw.viewer(World.stub_scene(:@cards => [named], :@index => 0))
  falsy "so the viewer does not say it twice", SpeakCapture.lines.join.include?("Mega #{item}. #{item}")
end

Suite.define("bw mystery gift: the download's carousel says each gift it moves to") do
  bw = PokeAccess::BWMysteryGift
  mew = MgSpecMon.new(:MEW)
  begin
    bw.download(:internet)
    bw.note_gifts([[7, 0, mew, "Mew"], [8, 1, :MASTERBALL, "Master Ball"]])
    SpeakCapture.clear
    bw.painted([["Mew", 0, 14]])
    eq "the first gift, and that it is a Pokemon, queued", SpeakCapture.log,
       [["Mew, #{PokeAccess::I18n.t(:mgift_kind_pokemon)}", false]]
    SpeakCapture.clear
    bw.painted([["Mew", 0, 14]])
    silent "the same gift repainted each frame is said once"
    bw.painted([["Master Ball", 0, 14]])
    eq "moving to an item cuts in", SpeakCapture.log,
       [["Master Ball, #{PokeAccess::I18n.t(:mgift_kind_item)}", true]]
    SpeakCapture.clear
    bw.painted([["Money", 0, 0]])
    silent "a paint that is no pending gift is not the carousel's"
  ensure
    bw.download(nil)
  end
  SpeakCapture.clear
  bw.painted([["Mew", 0, 14]])
  silent "and with the download closed nothing is"
end

# The password download: the password is typed first, then the gifts are decrypted and the matching one's sprite drops
# in; a gift the player already has, or no match, is the game's to say.
Suite.define("bw mystery gift: the password download says the gift its password matches") do
  bw = PokeAccess::BWMysteryGift
  mew = MgSpecMon.new(:MEW)
  gifts = [[7, 0, mew, "Mew Gift", "", nil, "MEWPASS"], [8, 1, :MASTERBALL, "Ball Gift", "", nil, "BALL"],
           [9, 1, "RARECANDY x3", "Candy Gift", "", nil, "CANDY"]]
  had = $player
  begin
    $player = Struct.new(:mystery_gifts).new([[8]])
    bw.download(:password)
    bw.note_password("MEWPASS")
    SpeakCapture.clear
    bw.note_gifts(gifts)
    eq "the species its sprite shows, and that it is a Pokemon, queued", SpeakCapture.log,
       [["#{PokeAccess::Data.species_name(:MEW)}, #{PokeAccess::I18n.t(:mgift_kind_pokemon)}", false]]
    bw.download(:password)
    bw.note_password("CANDY")
    SpeakCapture.clear
    bw.note_gifts(gifts)
    eq "an item given as several is its item", SpeakCapture.lines,
       ["#{PokeAccess::Data.item_name(:RARECANDY)}, #{PokeAccess::I18n.t(:mgift_kind_item)}"]
    bw.download(:password)
    bw.note_password("BALL")
    SpeakCapture.clear
    bw.note_gifts(gifts)
    silent "a gift already received is left to the game's own message"
    bw.download(:password)
    bw.note_password("NOPE")
    SpeakCapture.clear
    bw.note_gifts(gifts)
    silent "and so is a password that matches nothing"
    bw.download(:internet)
    bw.note_password("MEWPASS")
    SpeakCapture.clear
    bw.note_gifts(gifts)
    silent "the internet download names its gifts on its carousel, not here"
  ensure
    bw.download(nil)
    $player = had
  end
end
