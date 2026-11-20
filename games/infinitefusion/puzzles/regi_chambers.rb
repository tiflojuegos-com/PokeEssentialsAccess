# The three chambers of the Sealed Chamber (map 813), one per statue, each ended by touching its statue: the left one
# (switch 684) takes rocks pushed onto metal plates, the middle one (685) seven rocks slid into a column, the right one
# (686) plates stepped on in an order. The plates show a metal by their tile: 841 gold, 848 bronze, 862 stone and 872
# silver. The left chamber wants a rock on every gold and bronze plate (events 68, 69, 73, 74, 75 and 77) and none on
# the others; the middle one the rocks (1, 2, 3, 7, 8, 9 and 10) on x 42, y 14 to 20; the right one the letters
# "ssBSBGG" in var 1122 (stone, stone, bronze, silver, bronze, gold, gold), where the left bronze plate (event 85) only
# counts stepped on up or down and the silver one (event 66) only from a side; a wrong order starts over at the seventh
# letter or stepping on the entrance row (events 89 to 91, y 18). The braille pictures are said as the text they spell only
# with the Regi tablet in the bag, which is when the game deciphers them.
PokeAccess::Game.define("infinitefusion") do
  braille_texts = {
    "braille_icesteel" => "Go from rock bottom to the top of the podium",
    "braille_rockice" => "In line to the statue all stones must queue",
    "braille_steelrock" => "Most precious are the rarest they must remain untarnished"
  }
  on_picture do |name, _args|
    text = braille_texts[name]
    deciphered = PokeAccess::Engine.bag_quantity(:REGITABLET).to_i > 0
    PokeAccess.speak(PokeAccess::I18n.t(deciphered ? text : :ifp_braille), true) if text
  end
  gold = :ifp_plate_gold
  bronze = :ifp_plate_bronze
  stone = :ifp_plate_stone
  silver = :ifp_plate_silver
  rocks = [1, 2, 3, 7, 8, 9, 10]
  braille = [80, 92, 93, 94, 95, 96, 97, 98, 99]
  column = (14..20).map { |y| { :at => [42, y], :label => :ifp_rock_goal, :assist => true } }
  in_column = lambda do
    rocks.select do |id|
      ev = $game_map.events[id]
      ev && ev.x == 42 && ev.y >= 14 && ev.y <= 20
    end.length
  end
  letters = lambda do
    order = $game_variables[1122]
    order.is_a?(String) ? order.length : 0
  end
  open_in = lambda do |box, switch|
    lambda { box.call && !$game_switches[switch] }
  end

  mechanic(:state, 813, :part => :steel_rock) do
    auto
    name [75, 68, 73], bronze
    name [77, 74, 69], gold
    name [67, 72], stone
    name [76, 70], silver
    name 33, :ifp_statue_left
    count :ifp_plates_right, :selfs => [[68, 69, 73, 74, 75, 77], "A", 813], :of => 6, :assist => true
    watch :switch => 684, :say => :ifp_chamber_left_open
    solved(nil, :quiet => true) { $game_switches[684] }
    phase open_in.call(at(14, 24, 18, 31), 684), :title => :ifp_steel_rock_title, :entry_title => true, :hint => :ifp_steel_rock_hint
  end

  mechanic(:state, 813, :part => :rock_ice) do
    auto
    name 46, :ifp_statue_middle
    count :ifp_rocks_in_column, :value => in_column, :of => 7, :assist => true
    watch :switch => 685, :say => :ifp_chamber_middle_open
    solved(nil, :quiet => true) { $game_switches[685] }
    phase open_in.call(at(37, 48, 11, 28), 685), :title => :ifp_rock_ice_title, :entry_title => true, :hint => :ifp_rock_ice_hint,
          :spots => column
  end

  mechanic(:state, 813, :part => :ice_steel) do
    auto
    name [78, 84], gold
    name [85, 86], bronze
    name [87, 88], stone
    name 66, silver
    name 65, :ifp_statue_right
    count :ifp_plates_order, :value => letters, :of => 7, :assist => true
    watch :switch => 686, :say => :ifp_chamber_right_open
    solved(nil, :quiet => true) { $game_switches[686] }
    phase open_in.call(at(61, 71, 17, 31), 686), :title => :ifp_ice_steel_title, :entry_title => true, :hint => :ifp_ice_steel_hint
  end

  mechanic(:state, 813, :part => :braille) do
    auto
    name braille, :ifp_braille, :grouped => true
  end
end
