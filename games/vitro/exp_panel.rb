# Vitro's experience panel (0107_ExpMenu, PartyExpScreen). The battle no longer says what its Pokemon gain (0106_Experiencia2):
# a panel per member paints it for two seconds, with no key to wait for, its level already the new one. The members that gain
# something are said as their panels paint, as the battle's messages would; the level-up has its own message after it.
module PokeAccess
  module VitroExpPanel
    # Runs a panel's paint (the block) and says what it wrote, as written.
    def self.panel(screen, index)
      rows = PokeAccess::PaintCapture.sample { yield }
      say(screen, index, rows)
    end

    # A panel's line, for a member with a gain: the panel paints the others too, with no figure.
    def self.say(screen, index, rows)
      gains = PokeAccess.ivar(screen, :@filtered_exp_data)
      return unless gains && gains[index].to_i > 0
      PokeAccess.say_dialogue(rows.map { |row| row[0] }.join(", "))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  around("PartyExpScreen", :draw_pokemon_info) do |screen, nxt, args|
    PokeAccess::VitroExpPanel.panel(screen, args[2]) { nxt.call }
  end
end
