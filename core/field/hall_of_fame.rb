module PokeAccess
  # Hall of fame: the member panels (writePokemonData), the banner (writeWelcome) and the closing trainer box
  # (writeTrainerData), bound by bind to the vanilla scenes and to a profile's clones.
  module HallOfFame
    # The vanilla spellings, one per era.
    FAMILY = ["HallOfFameScene", "HallOfFame_Scene"]

    @box_armed = false
    @box = nil

    # A member as nickname, species and level (or "egg"), for a panel that painted nothing.
    def self.member_text(pk)
      return nil unless pk
      return PokeAccess::I18n.t(:hof_egg) if (pk.egg? rescue (pk.isEgg? rescue false))
      nm = pk.name.to_s
      sp = PokeAccess::Data.species_name(pk.species)
      who = (sp && !sp.to_s.empty? && sp.to_s != nm) ? "#{nm}, #{sp}" : nm
      lvl = (pk.level rescue nil)
      lvl ? PokeAccess::I18n.t(:hof_member, :who => who, :level => lvl) : who
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True while the scene is browsing, not animating the entry (a redraw then interrupts): writePokemonData's
    # second argument is a record number (-1 or absent in the animation), or the class has no pbStartSceneEntry.
    def self.viewer?(scene, args)
      n = args[1]
      return true if n.is_a?(Integer) && n > -1
      !scene.respond_to?(:pbStartSceneEntry)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Binds the panel, banner and trainer-box readers, all reading what is painted, to one scene class; answers
    # whether the panel one took.
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

      PokeAccess::Hooks.around_hook(cname, :writeTrainerData, :optional => true) do |_s, nxt, _a|
        PokeAccess::HallOfFame.arm_box
        begin
          nxt.call
        ensure
          PokeAccess::HallOfFame.disarm_box
        end
      end
      panel
    end

    # Arms the reading of the trainer box for the span of writeTrainerData.
    def self.arm_box; @box_armed = true; end

    # Ends writeTrainerData's span: a box no message took as its head is said on its own, queued.
    def self.disarm_box
      @box_armed = false
      return unless @box
      head = PokeAccess.take_head
      head == @box ? PokeAccess.speak(head, false) : PokeAccess.before_next_line(head)
      @box = nil
    end

    # Hands the first text a window takes while armed, the trainer box, to the congratulation as its head, so a
    # message read by pages cannot cut it.
    def self.note_box(text)
      return unless @box_armed
      t = box_text(text)
      return if t.empty?
      @box_armed = false
      @box = t
      PokeAccess.before_next_line(t)
    end

    # A box's rows as spoken: one per <br>, each label kept apart from the value <r> aligns right.
    def self.box_text(text)
      rows = text.to_s.split(/<\s*br\s*\/?\s*>/i).map { |r| PokeAccess.clean(r.gsub(/<\s*r\s*>/i, " ")) }
      rows.reject { |r| r.empty? }.join(", ")
    end

    # Speaks the banner once, deduped on its text.
    def self.say_welcome(scene, t)
      return if t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(scene, :hof_welcome, t.to_s)
      PokeAccess.speak_clean(t, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Speaks one member panel as painted, every row kept (a number and a win count may be the same figure), or
    # member_text when it painted nothing, then what only the sprite shows; in the PC viewer the record's header
    # leads it when the record changes and the member's place in its team follows. Deduped per scene by object
    # identity, so two equal members both read.
    def self.say_panel(scene, args)
      pk = args[0]
      rows = PokeAccess::PaintCapture.take(:hof_panel) || []
      key = pk ? pk.object_id : nil
      return unless key.nil? || PokeAccess::Cursor.changed?(scene, :hof_pk, key)
      viewer = viewer?(scene, args)
      head, rows = viewer ? split_header(rows, args[1]) : [nil, rows]
      t = PokeAccess::PaintCapture.text(rows, false)
      t = member_text(pk).to_s if t.to_s.strip.empty?
      parts = [t] + sprite_marks(pk) + [viewer ? place(scene) : nil]
      line = parts.compact.reject { |p| p.to_s.strip.empty? }.join(", ")
      line = "#{head}. #{line}" if head && PokeAccess::Cursor.changed?(scene, :hof_record, head)
      PokeAccess.speak_clean(line, viewer)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The PC viewer's record header, its label and the record's number painted after it joined ("Hall of Fame No.
    # 3"), and the panel's other rows; no header where no row paints the number after a label.
    def self.split_header(rows, number)
      i = rows.index { |r| PokeAccess.clean(r.to_s) == number.to_s }
      return [nil, rows] unless i && i > 0
      [PokeAccess.clean("#{rows[i - 1]} #{rows[i]}"), rows[0, i - 1] + rows[(i + 1)..-1]]
    end

    # What only a member's sprite shows, as words: its form's name (one made of marks alone, by the mark's name) and
    # whether it is shiny; nothing for an egg.
    def self.sprite_marks(pk)
      return [] if pk.nil? || (pk.egg? rescue (pk.isEgg? rescue false))
      marks = [PokeAccess.clean(PokeAccess::DexEntry.form_name(PokeAccess::Data.optional(:form_name, pk)).to_s)]
      marks.push(PokeAccess::I18n.t(:pk_shiny)) if PokeAccess::Party.shiny?(pk)
      marks.reject { |m| m.empty? }
    end

    # The member's place in its team as the viewer's grid shows it ("2 de 5"), from the scene's @battlerIndex and the
    # Pokemon in its @hallEntry (Fire Ash's records keep numbers after them); nil without them or positions left out.
    def self.place(scene)
      idx = PokeAccess.ivar(scene, :@battlerIndex)
      team = PokeAccess.ivar(scene, :@hallEntry)
      return nil unless idx.is_a?(Integer) && team.is_a?(Array)
      size = team.reject { |m| m.is_a?(Integer) }.length
      return nil unless idx >= 0 && idx < size
      PokeAccess::Verbosity.position(idx + 1, size)
    end
  end
end

PokeAccess::Hooks.variants(PokeAccess::HallOfFame::FAMILY, :writePokemonData, "hall_of_fame") do |cname|
  PokeAccess::HallOfFame.bind(cname)
end

# writeTrainerData's box is a Window_AdvancedTextPokemon, read as it takes its text (HallOfFame.note_box).
PokeAccess::Hooks.after_hook("Window_AdvancedTextPokemon", :text=) do |_w, _r, args|
  PokeAccess::HallOfFame.note_box(args[0])
end
