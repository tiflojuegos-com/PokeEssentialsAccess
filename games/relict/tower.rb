# Destiny Tower's floor events as the screen shows them: an item sprite by the class it draws (Create events.rb
# copies the templates as <template>_copy<id>_<suffix>), a dialogue Pokemon by its species, the stairs only once the
# minimap has them, and the "?" bubble of Event Indicators over whoever carries it.
module PokeAccess
  module RelictTower
    # The copies createPokemonEventsDungeon lays on a floor: template and suffix (item symbol, GOLD_<n>, species).
    COPY = /\A(item|gold|dialogue_poke)_copy\d+_(.+)\z/

    # The item sprites, by the word for the class each one draws.
    ITEM_SPRITES = { "item_ball" => :rel_item_ball, "item_tm" => :rel_item_tm, "item_berry" => :rel_item_berry,
                     "item_potion" => :rel_item_potion, "item_usual" => :loc_object, "item_gold" => :rel_item_gold }

    # The name of an event these rules cover, or nil to leave it to the core; a copy already picked up (its sprite
    # cleared) keeps its class, so its internal name is never said.
    def self.event_name(ev)
      m = COPY.match(ev.name.to_s)
      return species(m[2]) || m[2].split("_")[0].capitalize if m && m[1] == "dialogue_poke"
      key = ITEM_SPRITES[ev.character_name.to_s] || (m && (m[1] == "gold" ? :rel_item_gold : :loc_object))
      return nil unless key
      it = (m && m[1] == "item") ? item(m[2]) : nil
      it ? PokeAccess::I18n.t(:loc_object_named, :name => it) : PokeAccess::I18n.t(key)
    rescue StandardError
      nil
    end

    # The item a floor copy gives, by the symbol its name ends in, while name_items is on; else nil.
    def self.item(sym)
      return nil unless (PokeAccess::Config.name_items rescue true)
      _id, nm = PokeAccess::Data.item_id(sym.upcase)
      (nm && !nm.to_s.empty?) ? nm.to_s : nil
    end

    # A dialogue Pokemon's species name, from the symbol its name ends in (a form's too: SLOWKING_1).
    def self.species(sym)
      nm = PokeAccess::Data.species_name(sym.to_sym)
      (nm && !nm.to_s.strip.empty?) ? nm.to_s : nil
    end

    # True for an event drawn with an item sprite, an object whatever it runs.
    def self.item?(ev)
      ITEM_SPRITES.key?((ev.character_name.to_s rescue ""))
    end

    # True for the stairs of a floor whose minimap still hides them (DungeonLayoutCreate.rb: sawStairs unset).
    def self.unseen_stairs?(ev)
      return false unless (ev.name.to_s rescue "").include?("stairs")
      return false unless ($game_map.metadata.has_flag?("dungeonDisplay") rescue false)
      !($PokemonGlobal.sawStairs rescue true)
    end

    # True while Event Indicators draws its bubble over the event (EventIndicator#visible, set on every update).
    def self.indicator?(ev)
      list = ($scene.spriteset.event_indicator_sprites rescue nil)
      sp = list.is_a?(Array) ? list[ev.id] : nil
      return false if sp.nil? || (sp.disposed? rescue true)
      (sp.visible rescue false) ? true : false
    rescue StandardError
      false
    end

    # A name with the indicator's mark while its bubble shows.
    def self.with_indicator(ev, name)
      indicator?(ev) ? "#{name}, #{PokeAccess::I18n.t(:rel_indicator)}" : name
    end
  end
end

PokeAccess::Game.define("relict") do
  override("PokeAccess::Locator", :target_name) do |_mod, original, args|
    ev = args[0]
    if ev.is_a?(PokeAccess::Locator::SurfaceTarget)
      original.call
    else
      tag = (PokeAccess::Tags.get($game_map.map_id, ev.id) rescue nil)
      own = (tag.nil? || tag.to_s.empty?) ? PokeAccess::RelictTower.event_name(ev) : nil
      PokeAccess::RelictTower.with_indicator(ev, own || original.call)
    end
  end
  override("PokeAccess::Locator", :event_category) do |_mod, original, args|
    PokeAccess::RelictTower.item?(args[0]) ? :objects : original.call
  end
  override("PokeAccess::Locator", :tag_hidden?) do |_mod, original, args|
    original.call || PokeAccess::RelictTower.unseen_stairs?(args[0])
  end
end
