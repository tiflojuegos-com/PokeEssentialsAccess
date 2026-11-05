module PokeAccess
  # Slateport's market (assign_market_vendors): the game puts a vendor on each market spot, so a spot is only a place to
  # stand, the events that run the market are no one to talk to, and a vendor's name on the map is an internal one, as is
  # that of the clerk in the clothes shop, just "vendor".
  module IF2Market
    STALLS = { "" => :if2_clothes_shop, "warm" => :if2_stall_warm, "hat" => :if2_stall_hat, "glasses" => :if2_stall_glasses,
               "headband" => :if2_stall_headband, "cold" => :if2_stall_cold, "mask" => :if2_stall_mask,
               "energyGuru" => :if2_stall_energy, "Happiness Check" => :if2_stall_happiness, "tm" => :if2_stall_tm,
               "incense" => :if2_stall_incense, "pokeballs" => :if2_stall_balls }.freeze
    VENDOR = /\Avendor(?:_(.*?))?(?:\.sl)?\z/
    MACHINERY = /\Amarket_/

    # What a vendor's stall is called, one the table does not know by the market's own word; nil for any other event.
    def self.stall_name(ev)
      m = VENDOR.match(ev.name.to_s)
      m ? PokeAccess::I18n.t(STALLS[m[1].to_s] || :if2_stall) : nil
    end

    # True for a market spot and for the events that put the vendors on them.
    def self.machinery?(ev)
      MACHINERY.match(ev.name.to_s) ? true : false
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  event_name { |ev| PokeAccess::IF2Market.stall_name(ev) }
  event_hidden { |ev| PokeAccess::IF2Market.machinery?(ev) }
end
