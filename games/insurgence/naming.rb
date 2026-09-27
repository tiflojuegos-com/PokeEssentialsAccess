module PokeAccess
  # What Insurgence's events are to the player where their names are the mappers' own labels: dormant Hoopa rings,
  # Manaphy statues (Heart Swap targets), the currents of the Deep Cavern, the secret base doors of the Pokemon Centres
  # (common event 6, "Secret_base_Entrance") and, once the Tesseract has brought them, the items of Tesseract_Spot_2.
  # Its clerks call Kernel.pbPokeMartWorker without brackets, its trainer sprites add a variant (trchar050_1) and its
  # Pokemon sprites a form (718_3); the soaring maps' shadow marker follows the player and is left out.
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
      it = PokeAccess::Locator.item_name(ev)
      it ? PokeAccess::I18n.t(:loc_object_named, :name => it) : nil
    rescue StandardError
      nil
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
    rescue StandardError
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
  override("PokeAccess::Locator", :target_name) do |_mod, original, args|
    ev = args[0]
    tag = (PokeAccess::Tags.get($game_map.map_id, ev.id) rescue nil)
    own = (tag.nil? || tag.to_s.empty?) && ev.respond_to?(:name) && !ev.is_a?(PokeAccess::Locator::SurfaceTarget)
    (own && PokeAccess::InsurgenceNames.name(ev)) || original.call
  end
  override("PokeAccess::Locator", :event_category) do |_mod, original, args|
    PokeAccess::InsurgenceNames.object?(args[0]) ? :objects : original.call
  end
  override("PokeAccess::Locator", :in_category?) do |_mod, original, args|
    PokeAccess::InsurgenceNames.hidden?(args[0]) ? false : original.call
  end
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
