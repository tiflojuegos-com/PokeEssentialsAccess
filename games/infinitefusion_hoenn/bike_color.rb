module PokeAccess
  # The paint menu of Mauville's bike shop (select_bike_color): a shift of the bike's hue or its reset to the default
  # shows only on the player's sprite, which each change repaints (refreshPlayerOutfit). The hue a change leaves is
  # said, cutting in, and the default as no dye.
  module IF2BikeColor
    # Runs the menu, its changes said meanwhile.
    def self.run
      @hue = hue
      yield
    ensure
      @hue = nil
    end

    def self.hue
      ($Trainer.bike_color rescue nil).to_i
    end

    # Says the hue a repaint inside the menu left, when it changed.
    def self.repainted
      return if @hue.nil?
      now = hue
      return if now == @hue
      @hue = now
      t = PokeAccess::I18n
      PokeAccess.speak(now == 0 ? t.t(:if_dye_off) : t.t(:if_hue, :n => now), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("select_bike_color", :around) { |_a, nxt| PokeAccess::IF2BikeColor.run { nxt.call } }
  kernel("refreshPlayerOutfit", :after) { |_a, _r| PokeAccess::IF2BikeColor.repainted }
end
