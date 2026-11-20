# Vinoville Town's gym (map 148, with the basement of map 162 below it): the floor is a maze where only the tiles of a hidden
# path are safe. A button (events 14, 28, 30 and 41) turns switch 79 on and the path's tiles, events 1 to 53 drawn with the
# same graphic, flash for a moment; any other tile on the sides sends the player to the basement. Events 54 and 55 are the two
# switches at the back, and once both are on (switch 80) the central corridor opens.
module PokeAccess
  module UraniumVinoville
    # The ids of the tiles that make the path before both switches are on, and after.
    def self.first_path; ids(1..5, 8..13, 15..27, 32..40, 43..53); end
    def self.final_path; ids(60, 62..77, 78, 80, 81, 83, 84, 91, 92, 93, 94, 96); end

    # The named points the assist lists for a path.
    def self.spots(list)
      list.map { |id| { :event => id, :label => :ura_pz_vino_way, :onto => true, :assist => true } }
    end

    # Where the basement's falls land; the entrance stairs, which also lead down, land elsewhere.
    def self.landings; [[19, 28], [27, 13], [27, 38], [27, 50], [35, 28]]; end

    def self.ids(*parts)
      parts.map { |part| part.is_a?(Range) ? part.to_a : [part] }.flatten
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 148) do
    auto
    name [14, 28, 30, 41], :ura_pz_button
    name [54, 55], :ura_pz_vino_switch
    arrival_hint :ura_pz_vino_rule
    solved(nil) { $game_switches[81] }
    phase lambda { !$game_switches[80] }, :quiet => true, :hint => :ura_pz_vino_hint,
          :spots => PokeAccess::UraniumVinoville.spots(PokeAccess::UraniumVinoville.first_path)
    phase lambda { $game_switches[80] }, :quiet => true, :hint => :ura_pz_vino_final_hint,
          :spots => PokeAccess::UraniumVinoville.spots(PokeAccess::UraniumVinoville.final_path)
  end

  mechanic(:state, 162) do
    auto
    PokeAccess::UraniumVinoville.landings.each { |to| sent_back :ura_pz_vino_fall, :maps => [148], :to => to }
  end
end
