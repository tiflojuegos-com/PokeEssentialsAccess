# Submerged Temple (maps 811, 812 and 815) and the way back to the Water Labyrinth (map 606). Map 811 has three doors,
# each with two slots (events 1 and 6, 17 and 20, 18 and 22) that take a Pokemon: of types Ice and Rock the top one
# (switches 470 and 729), Steel and Rock the left one (471 and 731), Steel and Ice the right one (472 and 730). The
# inscriptions are braille pictures shown by events with no graphic; the game deciphers them only with the Regi tablet in
# the bag, and so are they said here, as the text they spell, while without it they are only a braille inscription. In
# the tunnel of 812 pushing the first boulder wakes the Sharpedo (events 6, 18 and 19) until the tunnel is done (switch
# 742); in 815 the Sharpedo (event 8) comes with the entrance from 812 (switch 745). One that touches the player sends
# them back to the labyrinth's entrance (58, 9 of 606), the same place the tunnel's own exit door leads to from (33, 20)
# of 812.
PokeAccess::Game.define("infinitefusion") do
  braille = {
    "braille_lore1a" => "1. A thousand years ago we had nowhere to live",
    "braille_lore1b" => "We asked the great titan it made islands for us",
    "braille_lore2a" => "2. Our population grew land became scarce",
    "braille_lore2b" => "The exhausted great titan could create no more",
    "braille_lore3a" => "3. The great titan told us use what I gave you",
    "braille_lore3b" => "Rock ice and metal fused three new titans were born",
    "braille_lore4a" => "4. With their powers united Kanto rose from the sea",
    "braille_lore4b" => "Their labor finished the titans now rest here"
  }
  on_picture do |name, _args|
    text = braille[name]
    deciphered = PokeAccess::Engine.bag_quantity(:REGITABLET).to_i > 0
    PokeAccess.speak(PokeAccess::I18n.t(deciphered ? text : :ifp_braille), true) if text
  end

  slots = [
    { :events => [1, 6],   :name => :ifp_slot_top,   :opened => 729, :full => 470, :types => [:ICE, :ROCK] },
    { :events => [17, 20], :name => :ifp_slot_left,  :opened => 731, :full => 471, :types => [:STEEL, :ROCK] },
    { :events => [18, 22], :name => :ifp_slot_right, :opened => 730, :full => 472, :types => [:STEEL, :ICE] }
  ]
  type_words = lambda do |slot|
    slot[:types].map { |t| PokeAccess::Data.type_name(t).to_s }
  end

  mechanic(:state, 811) do
    auto
    slots.each do |slot|
      name slot[:events], lambda { |_ev|
        if PokeAccess::Puzzles.assist?
          a, b = type_words.call(slot)
          [:ifp_slot_typed, { :slot => PokeAccess::I18n.t(slot[:name]), :a => a, :b => b }]
        else
          slot[:name]
        end
      }, :grouped => true
      watch :switch => slot[:full], :label => slot[:name], :on => :ifp_slot_full, :off => :ifp_slot_empty
    end
    watch :switch => 729, :say => :ifp_door_top_active
    watch :switch => 731, :say => :ifp_door_left_active
    watch :switch => 730, :say => :ifp_door_right_active
    name [57, 60, 61, 62, 63, 64, 65, 66], :ifp_braille, :grouped => true
  end

  mechanic(:state, 812) do
    auto
    obstacle(/sharpedo/i, :moving => true)
    arrival_hint :ifp_shark_rule
    solved(nil, :quiet => true) { $game_switches[742] }
  end

  mechanic(:state, 815) do
    auto
    obstacle(/sharpedo/i, :moving => true)
    arrival_hint lambda { $game_switches[745] ? :ifp_shark_tunnel_rule : nil }
  end

  PokeAccess::Locator.move_cause(:if_temple_sharks) do |from, to, kind|
    sharks = kind == :map && to[2] == 606 && [to[0], to[1]] == [58, 9] &&
             (from[2] == 815 || (from[2] == 812 && [from[0], from[1]] != [33, 20]))
    sharks ? PokeAccess::I18n.t(:ifp_shark_back) : nil
  end
end
