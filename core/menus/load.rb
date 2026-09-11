# Load / continue screen. The save panel (player, badges, play time, pokedex, location) is drawn text, so
# the summary is announced when the screen opens, which also forgets the current map so a save on the same
# map_id still triggers announce_map_change. One reader for both eras: the arguments come in four shapes,
# but the map id is always the LAST one and the play time is whichever middle one answers
# playtime_seconds_of (a stats object or a raw frame count).
module PokeAccess
  module LoadPanel
    # The map id of the save: always the final argument.
    def self.map_id(args); args.last; end

    # The play time in seconds, from whichever middle argument carries it, or nil.
    def self.seconds(args)
      (args[3..-2] || []).each do |a|
        s = PokeAccess::Util.playtime_seconds_of(a)
        return s if s
      end
      nil
    rescue StandardError
      nil
    end

    # The badge count as the panel words it. A profile replaces it where the panel reuses that number for
    # something else: Awakening paints it as the story chapter.
    def self.badges_text(nb); PokeAccess::I18n.t(:tr_badges, :n => nb); end

    # Parts a profile appends after the map: what its own panel paints that the stock one does not. Empty
    # by default.
    def self.extras(_trainer, _args); []; end

    # The spoken summary of the save on offer, or nil when there is none to continue.
    def self.summary(args)
      return nil unless args[1] && args[2]
      trainer = args[2]
      parts = [PokeAccess::I18n.t(:load_save, :name => trainer.name)]
      nb = PokeAccess.attr_of(trainer, :numbadges, :badge_count)
      parts.push(badges_text(nb)) if nb
      seen = (trainer.pokedex.seen_count rescue nil)
      parts.push(PokeAccess::I18n.t(:load_dex, :n => seen)) if seen
      hm = PokeAccess::Util.playtime_parts(seconds(args))
      parts.push(PokeAccess::I18n.t(:load_play, :h => hm[0], :m => hm[1])) if hm
      nm = (PokeAccess::Locator.map_name(map_id(args)) rescue nil)
      parts.push(PokeAccess::I18n.t(:load_at, :map => nm)) if nm && !nm.to_s.empty?
      parts.concat((extras(trainer, args) rescue []).compact)
      parts.join(", ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Engine.scene_classes("PokemonLoadScene", "PokemonLoad_Scene").each do |cls|
  PokeAccess::Hooks.before_hook(cls, :pbStartScene) { |_s, _a| PokeAccess::Locator.forget_map rescue nil }

  PokeAccess::Hooks.after_hook(cls, :pbStartScene) do |_s, _r, args|
    t = PokeAccess::LoadPanel.summary(args)
    PokeAccess.speak(t, false)
  end
end
