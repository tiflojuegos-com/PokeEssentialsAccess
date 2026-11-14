module PokeAccess
  module XenoverseNaming
    # This gen6 game translates map names through the same API as its load screen.
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

    # Only literal names and portrait paths are read; never evaluate event Ruby.
    MUGSHOT = /\A\s*fbNewMugshot\s*\(\s*(["'])([^"'\\#\r\n]+)\1\s*,\s*(["'])([^"'\\#\r\n]+)\3\s*,/

    # The actual leader uses a different overworld sprite and portrait filename.
    # Only this verified asset pair is an alias; names still use game translation.
    PORTRAIT_ALIASES = { "capopalestra1" => "ludopoli/danilo" }.freeze

    def self.sprite_key(path)
      path.to_s.tr('\\', '/').split('/').last.to_s.sub(/\.png\z/i, '').downcase
    end

    def self.own_portrait?(path, sprite)
      key = sprite_key(sprite)
      return true if sprite_key(path) == key
      normalized = path.to_s.tr('\\', '/').sub(/\.png\z/i, '').downcase
      PORTRAIT_ALIASES[key] == normalized
    end

    CENTER_START = /\A\s*(?:Kernel\.)?pbSetPokemonCenter(?:\(\s*\))?\s*\z/

    # These centers share their town's name and omit HealingSpot metadata. Read
    # their unchanging nurse event, not a respawn marker in a home or cutscene.
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

    # Only an unconditional action-button nurse with a literal initial marker
    # and Recover All for the whole party identifies this profile's center.
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

    # Forget file-derived names when a map/load resets the shared world caches.
    def self.forget_centers; @centers = {}; end

    # Keep meaningful names intact, without repeating core work for other events.
    # Fullbox localizes its literal speaker using this same map-specific table.
    def self.event_name(event)
      locator = PokeAccess::Locator
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
  override("PokeAccess::Locator", :game_map_name) do |locator, original, args|
    PokeAccess::XenoverseNaming.map_name(locator, args[0]) || original.call
  end
  override("PokeAccess::MapMeta", :pokecenter?) do |metadata, original, args|
    original.call || PokeAccess::XenoverseNaming.pokecenter?(metadata, args[0])
  end
  event_name { |event| PokeAccess::XenoverseNaming.event_name(event) }
end
