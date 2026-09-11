module PokeAccess
  # Hall of fame entry sequence, which draws team and banner text directly: writePokemonData per member and
  # writeWelcome for the banner, on HallOfFameScene (gen-6) and HallOfFame_Scene (modern). It is a FAMILY:
  # fangames clone the scene per records hall (Fire Ash ships six more), so the readers live in bind, which
  # core calls for the vanilla spellings and a profile for its clones.
  module HallOfFame
    # The vanilla spellings, one per era.
    FAMILY = ["HallOfFameScene", "HallOfFame_Scene"]

    # The spoken hall-of-fame line for a member: nickname, species and level (or "egg"). The FALLBACK for a
    # panel that painted nothing; what the panel paints is richer (dex number, sex symbol, trainer id) and
    # is what the capture reads.
    def self.member_text(pk)
      return nil unless pk
      return PokeAccess::I18n.t(:hof_egg) if (pk.egg? rescue (pk.isEgg? rescue false))
      nm = pk.name.to_s
      sp = PokeAccess::Data.species_name(pk.species)
      who = (sp && !sp.to_s.empty? && sp.to_s != nm) ? "#{nm}, #{sp}" : nm
      lvl = (pk.level rescue nil)
      lvl ? PokeAccess::I18n.t(:hof_member, :who => who, :level => lvl) : who
    rescue StandardError
      nil
    end

    # True while the scene is BROWSING rather than playing the entry animation, which is when a redraw must
    # interrupt the line before it instead of queueing behind it. Two things say so, and a clone needs only
    # one: the second argument of writePokemonData carries the record number in the PC viewer and -1 (or
    # nothing) during the animation, and a class with no pbStartSceneEntry has no animation at all, so every
    # draw of it is a browse. Fire Ash's team viewer is that second case -- one argument, no animation,
    # redrawn on each cursor move -- and queueing there read the whole walk instead of the member the player
    # stopped on. Every other hall of the sixteen sources has both the animation and the second argument.
    def self.viewer?(scene, args)
      n = args[1]
      return true if n.is_a?(Integer) && n > -1
      !scene.respond_to?(:pbStartSceneEntry)
    rescue StandardError
      false
    end

    # Binds the family's readers to one scene class and answers whether the PANEL one took (a banner without
    # a panel is a hall nobody can read). Both are CAPTURED rather than composed, since vanilla and every
    # clone paint their own words per language build. Each is optional and re-registering a class is
    # harmless.
    def self.bind(cname)
      panel = PokeAccess::Hooks.around_hook(cname, :writePokemonData, :optional => true) do |scene, nxt, args|
        PokeAccess::PaintCapture.arm(:hof_panel)
        begin
          nxt.call
        ensure
          PokeAccess::HallOfFame.say_panel(scene, args)
        end
      end

      PokeAccess::Hooks.around_hook(cname, :writeWelcome, :optional => true) do |scene, nxt, _a|
        PokeAccess::PaintCapture.arm(:hof_welcome)
        begin
          nxt.call
        ensure
          t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:hof_welcome))
          t = PokeAccess::I18n.t(:hof_welcome) if t.to_s.strip.empty?
          PokeAccess::HallOfFame.say_welcome(scene, t)
        end
      end
      panel
    end

    # Speaks the banner once. The panel dedups on the member; this one has nothing of its own to dedup on,
    # so it keys on the text -- which also makes binding a class twice harmless, as the header claims.
    def self.say_welcome(scene, t)
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :hof_welcome, t.to_s)
      PokeAccess.speak_clean(t, false)
    rescue StandardError
      nil
    end

    # Speaks one member panel: what it painted (dex number, name with its sex symbol, level, trainer id and,
    # in the viewer, the record header -- all words the per-language builds swap), or the composed line when
    # the copy painted nothing. Deduped per scene by OBJECT IDENTITY, so a redraw of the same member is
    # silent while two members that compare equal both read.
    def self.say_panel(scene, args)
      pk = args[0]
      t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:hof_panel))
      key = pk ? pk.object_id : nil
      return unless key.nil? || PokeAccess::Cursor.changed?(scene, :hof_pk, key)
      t = member_text(pk).to_s if t.to_s.strip.empty?
      PokeAccess.speak_clean(t, viewer?(scene, args))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.variants(PokeAccess::HallOfFame::FAMILY, :writePokemonData, "hall_of_fame") do |cname|
  PokeAccess::HallOfFame.bind(cname)
end
