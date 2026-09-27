# Load screen: the continue panel is spoken as the screen opens, from its own paint (else a summary composed from
# the save), then the saved team; opening also forgets the current map, so loading onto it still announces it.
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

    # The badge count as the composed summary words it.
    def self.badges_text(nb); PokeAccess::I18n.t(:tr_badges, :n => nb); end

    # Parts a profile appends: what its own panel draws that is not text (icons). Empty by default.
    def self.extras(_trainer, _args); []; end

    # Brackets a panel's refresh: a continue panel keeps its painted lines, minus its title (the focused command).
    def self.capture(panel)
      return yield unless PokeAccess.ivar(panel, :@isContinue)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      title = PokeAccess.clean(PokeAccess.ivar(panel, :@title).to_s)
      lines = lines_of(pairs.reject { |p| PokeAccess.clean(p[0].to_s) == title })
      panel.instance_variable_set(:@access_lines, lines) unless lines.empty?
      ret
    end

    # The panel's lines from its paint, each row joined left to right; a profile may split a shared row.
    def self.lines_of(pairs)
      PokeAccess::PaintCapture.lines(pairs)
    end

    # The lines the scene's continue panel painted, or an empty list.
    def self.painted(scene)
      sprites = PokeAccess.ivar(scene, :@sprites)
      return [] unless sprites.is_a?(Hash)
      panel = sprites.values.find { |s| PokeAccess.ivar(s, :@access_lines) }
      panel ? PokeAccess.ivar(panel, :@access_lines) : []
    end

    # The saved team as its icons show it: the species, or an egg.
    def self.team(trainer)
      team_line((trainer.party rescue nil))
    end

    # The team line for the Pokemon a screen draws as icons, species or egg each; nil for none.
    def self.team_line(party)
      return nil unless party.is_a?(Array) && !party.empty?
      names = party.map do |pk|
        (pk.egg? rescue false) ? PokeAccess::I18n.t(:pty_egg) : PokeAccess::Data.species_name(pk.species).to_s
      end
      PokeAccess::I18n.t(:load_party, :list => names.join(", "))
    rescue StandardError
      nil
    end

    # The spoken summary of the save on offer, or nil when there is none to continue.
    def self.summary(args, scene = nil)
      return nil unless args[1] && args[2]
      trainer = args[2]
      lines = painted(scene)
      parts = lines.empty? ? [composed(trainer, args)] : lines.dup
      parts.push(team(trainer))
      parts.concat((extras(trainer, args) rescue []))
      parts.compact.join(". ")
    rescue StandardError
      nil
    end

    # The panel's content worded by the mod, from the save's own data.
    def self.composed(trainer, args)
      parts = [PokeAccess::I18n.t(:load_save, :name => trainer.name)]
      nb = PokeAccess.attr_of(trainer, :numbadges, :badge_count)
      parts.push(badges_text(nb)) if nb
      seen = (trainer.pokedex.seen_count rescue nil)
      parts.push(PokeAccess::I18n.t(:load_dex, :n => seen)) if seen
      hm = PokeAccess::Util.playtime_parts(seconds(args))
      parts.push(PokeAccess::I18n.t(:load_play, :h => hm[0], :m => hm[1])) if hm
      nm = (PokeAccess::Locator.map_name(map_id(args)) rescue nil)
      parts.push(PokeAccess::I18n.t(:load_at, :map => nm)) if nm && !nm.to_s.empty?
      parts.join(", ")
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonLoadPanel", :refresh, :optional => true) do |panel, nxt, _a|
  PokeAccess::LoadPanel.capture(panel) { nxt.call }
end

PokeAccess::Engine.scene_classes("PokemonLoadScene", "PokemonLoad_Scene").each do |cls|
  PokeAccess::Hooks.before_hook(cls, :pbStartScene) { |_s, _a| PokeAccess::Locator.forget_map rescue nil }

  # A container: the panels are built and painted inside, and a guard would skip their capture.
  PokeAccess::Hooks.after_hook(cls, :pbStartScene, :hook_container => true) do |scene, _r, args|
    t = PokeAccess::LoadPanel.summary(args, scene)
    PokeAccess.speak(t, false)
  end
end
