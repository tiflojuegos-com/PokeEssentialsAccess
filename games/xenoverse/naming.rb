module PokeAccess
  # Xenoverse's names for maps, people, torches, chests and its Pokemon Centers, from the game's own data.
  module XenoverseNaming
    # A literal fbNewMugshot(name, portrait, ...) call: its name and portrait path. Event Ruby is never evaluated.
    MUGSHOT = /\A\s*fbNewMugshot\s*\(\s*(["'])([^"'\\#\r\n]+)\1\s*,\s*(["'])([^"'\\#\r\n]+)\3\s*,/

    # Overworld sheets whose portrait has another file name, by sheet: the portrait path the events pair with it.
    PORTRAIT_ALIASES = {
      "capopalestra1" => "ludopoli/danilo",
      "anziano + naso" => "ludopoli/vecchio",
      "scienziato" => "allenatori/professore"
    }

    # The codes an ambient torch's page holds: the terminator and comments.
    TORCH_NO_OP_CODES = [0, 108, 408]
    # A chest's conditional branch, if pbReceiveItem(PBItems::X), capturing the item.
    CONTAINER_ITEM = /\A\s*(?:Kernel\.)?pbReceiveItem\(\s*(?:::)?PBItems::([A-Z][A-Z0-9_]*)\s*\)\s*\z/
    # A nurse page's first command, pbSetPokemonCenter on its own.
    CENTER_START = /\A\s*(?:Kernel\.)?pbSetPokemonCenter(?:\(\s*\))?\s*\z/

    # The map's name as the game translates it (pbGetMapNameFromId, as its load screen), or nil.
    def self.map_name(locator, map_id)
      return nil unless locator.respond_to?(:pbGetMapNameFromId, true)
      name = locator.send(:pbGetMapNameFromId, map_id)
      return nil unless name.is_a?(String) && !name.strip.empty?
      text = PokeAccess.clean(name)
      text.empty? ? nil : text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The item a closed "closeopen" chest with no name of its own hands over, read from the one literal its live page
    # tests, or nil.
    def self.container_item_name(locator, event)
      return nil unless PokeAccess::Config.name_items && locator.container?(event)
      return nil if locator.container_open?(event) || !locator.placeholder_name?(locator.own_name(event))
      return nil unless sprite_key(event.character_name) == "closeopen"
      list = PokeAccess.ivar(event, :@list)
      return nil unless list.is_a?(Array) && !locator.live_talks?(event)
      ids = []
      list.each do |command|
        next unless command.code == 111 && command.parameters[0] == 12
        match = CONTAINER_ITEM.match(command.parameters[1].to_s)
        ids.push(match[1]) if match
      end
      return nil unless ids.uniq.length == 1
      name = PokeAccess::Data.item_id(ids[0])[1]
      name.is_a?(String) && !name.empty? ? name : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A sheet or portrait path's file name, lowercase and without extension.
    def self.sprite_key(path)
      path.to_s.tr('\\', '/').split('/').last.to_s.sub(/\.png\z/i, '').downcase
    end

    # True if the portrait path belongs to the event's own sheet, by name or by PORTRAIT_ALIASES.
    def self.own_portrait?(path, sprite)
      key = sprite_key(sprite)
      return true if sprite_key(path) == key
      normalized = path.to_s.tr('\\', '/').sub(/\.png\z/i, '').downcase
      PORTRAIT_ALIASES[key] == normalized
    end

    # True for an ambient Fiaccola: action button, and a live page with only a terminator and comments.
    def self.torch?(event)
      return false unless sprite_key(event.character_name) == "fiaccola"
      return false unless PokeAccess.ivar(event, :@trigger) == 0
      list = PokeAccess.ivar(event, :@list)
      list.is_a?(Array) && !list.empty? && list.all? { |command| TORCH_NO_OP_CODES.include?(command.code) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True if an indoor map holds the game's nurse (center_nurse?): these centers lack HealingSpot metadata.
    def self.pokecenter?(api, map_id)
      return false unless map_id.is_a?(Integer) && map_id > 0
      return false unless api.outdoor?(map_id) == false && api.respond_to?(:pbLoadRxData, true)
      @centers ||= {}
      return @centers[map_id] if @centers.key?(map_id)
      map = api.send(:pbLoadRxData, sprintf("Data/Map%03d", map_id))
      events = map.respond_to?(:events) ? map.events : nil
      return false unless events.is_a?(Hash)
      @centers[map_id] = events.values.any? { |event| center_nurse?(event) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True for a one-page, unconditional, action-button "infermiera" event that starts with pbSetPokemonCenter and
    # recovers the whole party.
    def self.center_nurse?(event)
      pages = event.respond_to?(:pages) ? event.pages : nil
      return false unless pages.is_a?(Array) && pages.length == 1
      page = pages[0]
      return false unless page.trigger == 0 && sprite_key(page.graphic.character_name) == "infermiera"
      condition = page.condition
      return false unless [:switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid].all? { |key| condition.send(key) == false }
      return false if [:actor_valid, :item_valid].any? { |key| condition.respond_to?(key) && condition.send(key) }
      list = page.list
      return false unless list.is_a?(Array) && !list.empty?
      first = list[0]
      return false unless first.code == 355 && first.indent == 0 && first.parameters.is_a?(Array)
      return false unless first.parameters.length == 1 && first.parameters[0].is_a?(String) && CENTER_START.match(first.parameters[0])
      return false if list[1] && list[1].code == 655
      list.any? { |command| command.code == 314 && command.parameters == [0] }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Forgets the centers read from the map files, when the world caches reset.
    def self.forget_centers
      @centers = {}
    end

    # The name for an event with no name of its own: a torch's word, or the one speaker whose portrait its live page
    # shows (MUGSHOT, own_portrait?) as the map translates it; nil leaves it to core.
    def self.event_name(event)
      locator = PokeAccess::Locator
      if torch?(event)
        name = locator.own_name(event)
        return PokeAccess::I18n.t(:xenoverse_torch) if name.downcase == "fiaccola" || locator.placeholder_name?(name)
        return nil
      end
      sprite = event.character_name.to_s
      return nil if sprite.empty? || !locator.placeholder_name?(locator.own_name(event))
      list = PokeAccess.ivar(event, :@list)
      return nil unless list.is_a?(Array)
      names = []
      locator.script_calls(list).each do |script|
        next unless script =~ /\A\s*fbNewMugshot\b/
        match = MUGSHOT.match(script)
        return nil unless match
        names.push(match[2]) if own_portrait?(match[4], sprite)
      end
      names.uniq!
      return nil unless names.length == 1 && names[0] !~ /\A\?+\z/
      return nil unless locator.event_name(event) == sprite
      return nil unless defined?(MessageTypes) && MessageTypes.respond_to?(:getFromMapHash) && $game_map
      name = MessageTypes.getFromMapHash($game_map.map_id, names[0])
      return nil unless name.is_a?(String) && !name.strip.empty?
      text = PokeAccess.clean(name)
      text.empty? ? nil : text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Caches.register(:xenoverse_centers) { PokeAccess::XenoverseNaming.forget_centers }

PokeAccess::Game.define("xenoverse") do
  override("PokeAccess::Locator", :item_name) do |locator, original, args|
    original.call || PokeAccess::XenoverseNaming.container_item_name(locator, args[0])
  end
  override("PokeAccess::Locator", :game_map_name) do |locator, original, args|
    PokeAccess::XenoverseNaming.map_name(locator, args[0]) || original.call
  end
  override("PokeAccess::MapMeta", :pokecenter?) do |metadata, original, args|
    original.call || PokeAccess::XenoverseNaming.pokecenter?(metadata, args[0])
  end
  event_name { |event| PokeAccess::XenoverseNaming.event_name(event) }
  event_category(:objects) { |event| PokeAccess::XenoverseNaming.torch?(event) }
end
