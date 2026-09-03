# The Fates compendiums (angels, demons and the nine legendary lists, scripts 0226-0237). Twelve separate
# screens that are the same screen twelve times: each file declares a row class, a viewer class holding the
# cursor, and a wrapper. Verified identical across all twelve -- the viewer keeps the focus in @select, the
# rows in @opciones (each row object exposing .nombre), and @interruptores with the game switch that marks an
# entry as discovered; when the switch is off the game itself replaces the name with "¿¿??".
#
# So one parameterised reader registered under the twelve viewer names covers all of them, instead of twelve
# near-identical files. Reading .nombre also means the "not yet registered" placeholder is spoken exactly as
# the game shows it, with no extra bookkeeping on our side.
module PokeAccess
  module AwakeningCompendium
    VIEWERS = ["ListaAngeles", "ListaDemonios", "ListaLegendarios",
               "ListaLegendarios1", "ListaLegendarios2", "ListaLegendarios3", "ListaLegendarios4",
               "ListaLegendarios5", "ListaLegendarios6", "ListaLegendarios7", "ListaLegendarios8",
               "ListaLegendarios9"]

    # True for a row the compendium has not registered yet. Those are written as punctuation, and a screen
    # reader either spells the characters out or says nothing at all -- "nothing at all" on a list of twelve
    # rows being the worse of the two. Matched on SHAPE rather than on the exact string: the placeholder is
    # non-ASCII and the game's copy of it need not be in the same encoding as this file, so a byte compare
    # could quietly never match. Anything with no letter and no digit in it is a placeholder.
    def self.placeholder?(name)
      name.to_s.gsub(/[^[:alnum:]]/, "").empty?
    rescue StandardError
      false
    end


    # Voices the focused entry once per change: its name, or the locked word where the compendium has not
    # registered it yet, and its position in the list.
    def self.focus(scene)
      idx = PokeAccess.ivar(scene, :@select)
      rows = PokeAccess.ivar(scene, :@opciones)
      return unless idx.is_a?(Integer) && rows.is_a?(Array) && idx >= 0 && idx < rows.length
      name = (rows[idx].nombre rescue nil)
      name = PokeAccess.clean(name.to_s).to_s.strip
      name = PokeAccess::I18n.t(:awk_glos_locked) if placeholder?(name)
      return if name.empty?
      PokeAccess::Cursor.announce(scene, :awk_comp, idx, true) do
        PokeAccess::I18n.t(:list_entry, :name => name, :n => idx + 1, :tot => rows.length)
      end
    rescue StandardError
      nil
    end

    # The detail sheet each viewer opens on the confirm key. Same screen twelve times again, but the method
    # carries its list's name, so the pairing is spelled out.
    SHEETS = { "ListaAngeles" => :pbDatosAngel, "ListaDemonios" => :pbDatosDemon,
               "ListaLegendarios" => :pbDatosLegen, "ListaLegendarios1" => :pbDatosLegen1,
               "ListaLegendarios2" => :pbDatosLegen2, "ListaLegendarios3" => :pbDatosLegen3,
               "ListaLegendarios4" => :pbDatosLegen4, "ListaLegendarios5" => :pbDatosLegen5,
               "ListaLegendarios6" => :pbDatosLegen6, "ListaLegendarios7" => :pbDatosLegen7,
               "ListaLegendarios8" => :pbDatosLegen8, "ListaLegendarios9" => :pbDatosLegen9 }

    # The sheet is read from what it PAINTS, not from the list's data: its name, its obtained state and its
    # two descriptions live in per-file constants (POKES_ANGE, DESCRIPCIONES_CORTAS_ANGE and eleven more
    # pairs), while the draw calls are the same two in all twelve.
    @pending = nil

    def self.sheet_on; @pending = []; end
    def self.sheet_off; @pending = nil; end

    def self.note(text)
      return if @pending.nil?
      t = PokeAccess.clean(text.to_s).to_s.strip
      @pending.push(t) unless t.empty?
    rescue StandardError
      nil
    end

    # One read per painted batch. The sheet draws everything and only then blocks, so by the first frame of
    # its loop the batch is complete; the "more information" key paints another and that becomes the next.
    def self.sheet_poll
      return if @pending.nil? || @pending.empty?
      t = @pending.join(". ")
      @pending = []
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # The text of a pbDrawTextPositions batch, which is an array of [text, x, y, ...] rows.
    def self.note_positions(rows)
      return unless rows.is_a?(Array)
      rows.each { |r| note(r.is_a?(Array) ? r[0] : r) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  PokeAccess::AwakeningCompendium::VIEWERS.each do |cname|
    after(cname, :update) { |s, _r, _a| PokeAccess::AwakeningCompendium.focus(s) }
  end
  PokeAccess::AwakeningCompendium::SHEETS.each do |cname, meth|
    around(cname, meth, :optional => true) do |_s, nxt, _a|
      PokeAccess::AwakeningCompendium.sheet_on
      begin; nxt.call; ensure; PokeAccess::AwakeningCompendium.sheet_off; end
    end
  end
  kernel("pbDrawTextPositions", :before) { |args, _r| PokeAccess::AwakeningCompendium.note_positions(args[1]) }
  kernel("drawTextEx", :before) { |args, _r| PokeAccess::AwakeningCompendium.note(args[5]) }
  poll_each_frame { PokeAccess::AwakeningCompendium.sheet_poll }
  # The "Z = Mas informacion" panel: a global function that paints its lore text into an own canvas and
  # blocks in an own loop, drawing through neither of the two calls captured above. args[2] is the whole
  # text; the same function also shows two battle tutorial notices, equally unread without this.
  kernel("carteles", :before) { |args, _r| PokeAccess.speak_clean(args[2].to_s, true) }
end
