module PokeAccess
  # Awakening's class/outfit picker (Fates_Menu_Personajes, a blocking loop inside initialize): the class focused in
  # @classArray (@select) for character @name as the screen paints it, its detail panel (Z) and its lore (Q).
  module AwakeningClasses
    # A constant of the picker's class, or nil.
    def self.table(name)
      PokeAccess.const_at("Fates_Menu_Personajes::#{name}")
    end

    # The class name the screen paints: its time-skip counterpart once the time-skip switch is on.
    def self.shown_class(cls)
      skips = table("TIMESKIP")
      switch = table("TIMESKIPSWITCH")
      on = switch && ($game_switches[switch] rescue false)
      (on && skips.is_a?(Hash) && skips[cls]) ? skips[cls] : cls
    end

    # The class line: a locked class as the ND picture paints it, with no name; an unlocked one by its name, level and
    # ability (less its ">" bullet), with its description in full; all of it on the info key.
    def self.line(who, cls)
      unless (::Fates_Utilities.checkIfHasClass(who, cls) rescue true)
        PokeAccess::Info.set_info(:text, PokeAccess::I18n.t(:aw_outfit_locked))
        return PokeAccess::I18n.t(:aw_outfit_locked)
      end
      shown = shown_class(cls)
      lvl = ($game_player.clases[who][cls] rescue nil)
      hab = PokeAccess.clean((table("HABS")[who][cls] rescue nil).to_s).sub(/\A>+\s*/, "")
      parts = [shown.to_s]
      parts.push(PokeAccess::I18n.t(:awk_class_level, :n => lvl)) unless lvl.nil?
      parts.push(PokeAccess::I18n.t(:awk_class_ability, :name => hab)) unless hab.empty?
      head = parts.join(", ")
      whole = PokeAccess.sentences([head, PokeAccess.clean((table("TEXTOS")[who][shown] rescue "").to_s)])
      PokeAccess::Info.set_info(:text, whole)
      PokeAccess::Verbosity.descriptions? ? whole : head
    end

    # The detail panel Z opens over the class (habs2_text: its path, battle ability and the upgrades of its level).
    def self.detail(scene, who, cls)
      shown = shown_class(cls)
      lvl = ($game_player.clases[who][shown] rescue nil) || 0
      PokeAccess.clean((scene.habs2_text(who, shown, lvl) rescue "").to_s)
    end

    # Runs the lore window (the block, its loop) with its title and lore said as it opens, and the class said again
    # once it closes.
    def self.lore(title, text)
      PokeAccess.speak(PokeAccess.clean("#{PokeAccess::I18n.t(:awk_class_lore, :name => title)}. #{text}"), true)
      begin
        yield
      ensure
        PokeAccess::Cursor.reset(PokeAccess::AwakeningOutfits, :aw_outfit)
      end
    end
  end

  # The focused class, or its detail panel while the panel is up, said on each change.
  AwakeningOutfits = SceneWatcher.reader("Fates_Menu_Personajes", :initialize, :aw_outfit) do |s|
    sel = PokeAccess.ivar(s, :@select)
    arr = PokeAccess.ivar(s, :@classArray)
    who = PokeAccess.ivar(s, :@name)
    ok = sel && arr.is_a?(Array) && sel >= 0 && sel < arr.length && !arr[sel].to_s.empty?
    next nil unless ok
    cls = arr[sel].to_s
    base = (PokeAccess.sprite(s, "Base").visible rescue false) ? true : false
    [[sel, base], lambda { base ? AwakeningClasses.detail(s, who, cls) : AwakeningClasses.line(who, cls) }]
  end
end

# The lore window Q opens, and the class line off the info key once the picker closes.
PokeAccess::Game.define("awakening") do
  around("Fates_Menu_Personajes", :showLoreWindow) do |_s, nxt, args|
    PokeAccess::AwakeningClasses.lore(args[0], args[1]) { nxt.call }
  end
  around("Fates_Menu_Personajes", :initialize) do |_s, nxt, _a|
    begin; nxt.call; ensure; PokeAccess::Info.clear_text; end
  end
end
