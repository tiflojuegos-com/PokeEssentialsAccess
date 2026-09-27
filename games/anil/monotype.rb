module PokeAccess
  # Monotype challenge type picker (Monotype Challenge plugin, nested MonotypeMenu::MonotypeMenu_Scene): a sprite
  # list over @type_list plus a trailing option, read from pbRedrawList (open and every cursor move), deduped, after
  # the title the list paints as it opens.
  module AnilMonotype
    # The focused type's spoken name; an entry is [display_name, type_symbol, starters], not a type id.
    def self.type_name(entry)
      return entry[0].to_s if entry.is_a?(Array)
      (GameData::Type.get(entry).name rescue (entry.respond_to?(:name) ? entry.name : entry.to_s))
    end

    # The focused type, or the trailing option: switch to the other list from the recommended one, else back.
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

    # Speaks the focused type when it changes, the list's first read queued after its title; the dedup lives on the
    # scene so it resets on reopen.
    def self.read(scene)
      t = text(scene)
      PokeAccess::Cursor.announce(scene, :mono_type, t, true, false) { t } unless t.nil?
    rescue StandardError
      nil
    end

    # Says the title the block paints (the list's create_overlay_title) as the list opens; returns the block's value.
    def self.title
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      t = PokeAccess::PaintCapture.lines(pairs).join(". ")
      PokeAccess.speak(t, true) unless t.empty?
      ret
    end
  end
end

PokeAccess::Game.define("anil") do
  after("MonotypeMenu::MonotypeMenu_Scene", :pbRedrawList) do |scene, _r, _a|
    PokeAccess::AnilMonotype.read(scene)
  end
  around("MonotypeMenu::MonotypeMenu_Scene", :create_overlay_title, :optional => true) do |_scene, nxt, _a|
    PokeAccess::AnilMonotype.title { nxt.call }
  end
end
