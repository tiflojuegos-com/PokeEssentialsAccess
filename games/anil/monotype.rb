module PokeAccess
  # Monotype challenge type picker (Monotype Challenge plugin). The class is NESTED --
  # MonotypeMenu::MonotypeMenu_Scene -- and registering the bare name bound nothing at all. An absent class
  # is normal cross-game variance, so it is silent by design and never reaches Hooks.missing: the whole
  # screen read nothing, with no error anywhere to find it by.
  #
  # A custom sprite list scrolled by @index over @type_list, with a trailing special option at
  # @type_list.length and no command window. pbRedrawList runs once on open and on every cursor move, so
  # the focused entry is read from there, deduped.
  module AnilMonotype
    # The focused type's spoken name. An entry is [display_name, type_symbol, starters], NOT a type id, so
    # handing it to GameData::Type raised and the rescue spoke the whole array's inspect.
    def self.type_name(entry)
      return entry[0].to_s if entry.is_a?(Array)
      (GameData::Type.get(entry).name rescue (entry.respond_to?(:name) ? entry.name : entry.to_s))
    end

    # The focused type, or the trailing option -- which is two different actions and the plugin labels it
    # accordingly: from the recommended list it switches to the other one, from that one it goes back.
    def self.text(scene)
      tl  = PokeAccess.ivar(scene, :@type_list)
      idx = PokeAccess.ivar(scene, :@index)
      return nil unless tl.is_a?(Array) && idx
      if idx >= tl.length
        return PokeAccess::I18n.t(PokeAccess.ivar(scene, :@primary_list) ? :mono_other : :mono_back)
      end
      PokeAccess::I18n.t(:mono_type, :type => type_name(tl[idx]))
    rescue StandardError
      nil
    end

    # Speaks the focused type when it changes; the dedup lives on the scene so it resets on reopen.
    def self.read(scene)
      t = text(scene)
      PokeAccess::Cursor.announce(scene, :mono_type, t, true) { t } unless t.nil?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("anil") do
  after("MonotypeMenu::MonotypeMenu_Scene", :pbRedrawList) do |scene, _r, _a|
    PokeAccess::AnilMonotype.read(scene)
  end
end
