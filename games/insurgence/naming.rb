module PokeAccess
  # Names for Insurgence's events whose names are the mappers' own labels: dormant Hoopa rings, Manaphy statues, the
  # Deep Cavern's currents, secret base doors and what Tesseract_Spot_2 holds. Its clerks call Kernel.pbPokeMartWorker
  # without brackets, and its sprite names add a variant or form number ("trchar050_1", "718_3").
  module InsurgenceNames
    # A current's name, by the way it carries the player.
    CURRENT = /\Acurrent_(up|down|left|right)\z/
    CURRENT_DIR = { "up" => :dir_up, "down" => :dir_down, "left" => :dir_left, "right" => :dir_right }
    # The common event every secret base door runs.
    SECRET_BASE_DOOR = 6

    # The name to say for an event of these families, or nil to leave it to the core.
    def self.name(ev)
      n = ev.name.to_s
      return current(n) if n =~ CURRENT
      return PokeAccess::I18n.t(:ins_hoopa_ring) if n == "Hoopa_Hole" && !PokeAccess::Locator.transfer_event?(ev)
      return PokeAccess::I18n.t(:ins_manaphy_statue) if n.index("HeartSwap_S") == 0 && statue?(ev)
      return PokeAccess::I18n.t(:ins_sb_door) if secret_base_door?(ev)
      return nil unless n.index("HeartSwap_S") == 0 || n == "Tesseract_Spot_2"
      it = (PokeAccess::Config.name_items rescue true) ? PokeAccess::Locator.item_name(ev) : nil
      return PokeAccess::I18n.t(:loc_object_named, :name => it) if it
      (n == "Tesseract_Spot_2" && tesseract_find(ev)) || PokeAccess::I18n.t(:loc_object)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What a Tesseract spot holds that is no item: a wild Pokemon by the species its sprite shows, or a boulder that
    # rolls by itself as a pushable object; else nil.
    def self.tesseract_find(ev)
      sp = PokeAccess::Locator.sprite_species(ev.character_name.to_s)
      return sp if sp
      PokeAccess::Routes::Effects.self_pushed?(ev) ? PokeAccess::I18n.t(:loc_pushable) : nil
    end

    # "Current, <direction>".
    def self.current(n)
      PokeAccess::I18n.t(:ins_current, :dir => PokeAccess::I18n.t(CURRENT_DIR[n[CURRENT, 1]]))
    end

    # True for a Manaphy statue's sprite.
    def self.statue?(ev)
      ev.character_name.to_s == "manaphy_statue"
    end

    # True for a secret base door: its page only calls the secret base entrance common event.
    def self.secret_base_door?(ev)
      list = PokeAccess.ivar(ev, :@list)
      return false unless list.is_a?(Array)
      codes = list.map { |c| (c.code rescue 0) }.reject { |c| c == 0 }
      codes == [117] && (list.find { |c| (c.code rescue 0) == 117 }.parameters[0] rescue nil) == SECRET_BASE_DOOR
    end

    # The families that are things, not people: currents, rings and statues.
    def self.object?(ev)
      n = ev.name.to_s
      !!(n =~ CURRENT) || n == "Hoopa_Hole" || (n.index("HeartSwap_S") == 0 && statue?(ev))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True for the soaring maps' marker that sits under the player (a parallel event named soar_stalker).
    def self.hidden?(ev)
      (ev.name.to_s rescue "") == "soar_stalker"
    end

    # A sprite name with a trailing variant or form number dropped ("trchar050_1", "718_3"), or nil without one.
    def self.base_sprite(g)
      g.to_s =~ /\A(trchar\d+|\d{3})_\d+\z/ ? $1 : nil
    end
  end
end

PokeAccess::Game.define("insurgence") do
  event_name { |ev| PokeAccess::InsurgenceNames.name(ev) }
  event_category(:objects) { |ev| PokeAccess::InsurgenceNames.object?(ev) }
  event_hidden { |ev| PokeAccess::InsurgenceNames.hidden?(ev) }
  override("PokeAccess::Locator", :shop_event?) do |_mod, original, args|
    original.call || !!PokeAccess::Locator.script_call_find(args[0]) { |s| s =~ /\bpbPokeMartWorker\b/ }
  end
  override("PokeAccess::Locator", :sprite_trainer_class) do |_mod, original, args|
    base = PokeAccess::InsurgenceNames.base_sprite(args[0])
    args[0] = base if base && base.index("trchar") == 0
    original.call
  end
  override("PokeAccess::Locator", :sprite_species) do |_mod, original, args|
    base = PokeAccess::InsurgenceNames.base_sprite(args[0])
    args[0] = base if base && base =~ /\A\d{3}\z/
    original.call
  end
end
