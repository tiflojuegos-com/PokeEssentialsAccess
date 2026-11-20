# Mirage Mansion's library (postgame): five events add one to var 31 (maps 151 to 153: two pages on 151, the May 1994 page on
# 152 that brings a ghost to fight and another page there, and the library's page; map 150's opening scene zeroes it), and from
# five on only the middle bookshelf of the three (map 153, event 3) answers; pulling its book opens the secret door (switch 187).
# The page in Trudly's storeroom (map 151, event 19) lies behind two crates (events 16 and 17) that go once var 31 reaches 4.
module PokeAccess
  module DHMirage
    COUNTED = [[151, 15], [151, 19], [152, 23], [152, 24], [153, 24]]
    LIBRARY = [153, 24]
    STOREROOM = [151, 19]
    CRATES = [16, 17]
    SHELF = 3

    # True when the page of event e of map m is still unread.
    def self.unread?(m, e)
      !$game_self_switches[[m, e, "A"]]
    end

    # True while the crates still close the way to the storeroom's page.
    def self.boxed?
      $game_variables[31] < 4
    end

    # True while the page of event e of map m is listed: unread, and in reach.
    def self.listed?(m, e)
      unread?(m, e) && !([m, e] == STOREROOM && boxed?)
    end

    # The counted events not done yet.
    def self.left
      COUNTED.select { |m, e| unread?(m, e) }.length
    end

    # The hint: the pages still missing, the library's one while it is unread and the storeroom's while the crates hide it;
    # else the shelf that answers.
    def self.hint
      n = left
      return :dh_pz_book_hint if n == 0
      t = PokeAccess::I18n
      parts = [t.t(:dh_pz_pages_hint, :n => n)]
      parts.push(t.t(:dh_pz_pages_library, :n => n)) if unread?(*LIBRARY)
      parts.push(t.t(:dh_pz_storeroom_page)) if unread?(*STOREROOM) && boxed?
      PokeAccess.sentences(parts)
    end

    # The bookshelf's name: with the assist, the one that answers once the five are done.
    def self.shelf(ev)
      PokeAccess::Puzzles.assist? && ev.id == SHELF && left == 0 ? :dh_pz_shelf_book : :dh_pz_shelf
    end

    # The events of map that are journal pages.
    def self.notes(map)
      COUNTED.select { |m, _e| m == map }.map { |_m, e| e }
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  [151, 152].each do |map|
    mechanic(:state, map) do
      auto
      name PokeAccess::DHMirage.notes(map), :dh_pz_journal_page, :when => lambda { |ev| PokeAccess::DHMirage.listed?(map, ev.id) }
      name PokeAccess::DHMirage::CRATES, :dh_pz_crates, :grouped => true, :when => lambda { |_ev| PokeAccess::DHMirage.boxed? } if map == 151
      watch :var => 31, :number => true, :label => :dh_pz_journal_pages
      solved { $game_switches[187] }
      hint lambda { PokeAccess::DHMirage.hint }
    end
  end
  mechanic(:state, 153, :part => :journal) do
    auto
    name PokeAccess::DHMirage.notes(153), :dh_pz_journal_page, :when => lambda { |ev| PokeAccess::DHMirage.unread?(153, ev.id) }
    watch :var => 31, :number => true, :label => :dh_pz_journal_pages
    solved { $game_switches[187] }
    hint lambda { PokeAccess::DHMirage.hint }
  end
  mechanic(:state, 153, :part => :library) do
    auto
    name [3, 4, 5], lambda { |ev| PokeAccess::DHMirage.shelf(ev) }, :when => lambda { |ev| ev.id == PokeAccess::DHMirage::SHELF || !PokeAccess::Puzzles.assist? }
    hide [4, 5], :assist => true
  end
end
