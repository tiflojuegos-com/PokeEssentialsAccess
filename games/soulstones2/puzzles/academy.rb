# Telescopium Academy (maps 151 to 154, one per floor): after Cara's scene (map 151, event 7: V31 = 3, V32 = V33 = 1) the
# floor's key books add to V32 and its former Ethereal Guild acolytes to V33, each setting its own self switch A; Artie
# lets the player up a floor once that floor's share is done, the ninth book gives one password and the seventh acolyte the
# other, each adding to V31, and Cara on the top floor (map 154, event 21) goes on with V31 = 5. The Elder's code (map 151,
# event 8) skips it all by setting S101; the core says that code with the assist, as the page compares it.
module PokeAccess
  module SS2Academy
    BOOKS = { 151 => [28, 11], 152 => [4], 153 => [3, 10, 16], 154 => [4, 7, 8] }
    ACOLYTES = { 152 => [9, 10], 153 => [22, 23, 26], 154 => [19, 20] }

    # True while the gathering runs: from Cara's scene until both passwords are known or the code skipped it.
    def self.running?
      v = $game_variables[31]
      v >= 3 && v < 5 && !$game_switches[101]
    end

    # True once an event of a floor has given what it had: its self switch A.
    def self.done?(map, id)
      $game_self_switches[[map, id, "A"]] ? true : false
    end

    # A shelf's name: with the assist, a key book still unread says so.
    def self.shelf(map, ev)
      key = (BOOKS[map] || []).include?(ev.id) && PokeAccess::Puzzles.assist? && running? && !done?(map, ev.id)
      key ? :ss2_pz_acad_key_book : :loc_sign_shelf
    end

    # An acolyte's name: with the assist, a former Guild member not yet asked says so.
    def self.acolyte(map, ev)
      PokeAccess::Puzzles.assist? && running? && !done?(map, ev.id) ? :ss2_pz_acad_ex_member : :ss2_pz_acad_acolyte
    end

    # What is left on the floor, said with the assist: the books and acolytes to go, or the way up once all are done.
    def self.hint(map)
      t = PokeAccess::I18n
      books = (BOOKS[map] || []).reject { |id| done?(map, id) }.length
      people = (ACOLYTES[map] || []).reject { |id| done?(map, id) }.length
      return t.t(:ss2_pz_acad_h_up) if books + people == 0
      t.t(:ss2_pz_acad_h_left, :books => books, :people => people)
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  PokeAccess::SS2Academy::BOOKS.each_key do |map|
    mechanic(:state, map) do
      auto
      name(/Book/, lambda { |ev| PokeAccess::SS2Academy.shelf(map, ev) },
           :when => lambda { |ev| PokeAccess::SS2Academy.shelf(map, ev) == :ss2_pz_acad_key_book })
      people = PokeAccess::SS2Academy::ACOLYTES[map]
      if people
        name(people, lambda { |ev| PokeAccess::SS2Academy.acolyte(map, ev) },
             :when => lambda { |ev| PokeAccess::Puzzles.assist? && PokeAccess::SS2Academy.running? && !PokeAccess::SS2Academy.done?(map, ev.id) })
        count :ss2_pz_acad_people, :selfs => [people, "A", map], :announce => false
      end
      count :ss2_pz_acad_books, :selfs => [PokeAccess::SS2Academy::BOOKS[map], "A", map], :announce => false
      active { PokeAccess::SS2Academy.running? }
      solved { !PokeAccess::SS2Academy.running? && $game_variables[31] >= 3 }
      hint lambda { PokeAccess::SS2Academy.hint(map) }
    end
  end
end
