# The twelve Fates compendium viewers (angels, demons, legendaries), all alike: the focus in @select, the rows
# in @opciones (.nombre); one reader registered under every name.
module PokeAccess
  module AwakeningCompendium
    VIEWERS = ["ListaAngeles", "ListaDemonios", "ListaLegendarios",
               "ListaLegendarios1", "ListaLegendarios2", "ListaLegendarios3", "ListaLegendarios4",
               "ListaLegendarios5", "ListaLegendarios6", "ListaLegendarios7", "ListaLegendarios8",
               "ListaLegendarios9"]

    # True for a row not registered yet, painted as punctuation: any name with no letter or digit (matched on
    # shape, since the non-ASCII placeholder's encoding may differ from this file's).
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
      name = PokeAccess.clean(name.to_s)
      name = PokeAccess::I18n.t(:awk_glos_locked) if placeholder?(name)
      return if name.empty?
      PokeAccess::Cursor.announce(scene, :awk_comp, idx, true) do
        PokeAccess::Verbosity.list_entry(name, idx + 1, rows.length)
      end
    rescue StandardError
      nil
    end

    # Viewer => the method that opens its detail sheet on the confirm key.
    SHEETS = { "ListaAngeles" => :pbDatosAngel, "ListaDemonios" => :pbDatosDemon,
               "ListaLegendarios" => :pbDatosLegen, "ListaLegendarios1" => :pbDatosLegen1,
               "ListaLegendarios2" => :pbDatosLegen2, "ListaLegendarios3" => :pbDatosLegen3,
               "ListaLegendarios4" => :pbDatosLegen4, "ListaLegendarios5" => :pbDatosLegen5,
               "ListaLegendarios6" => :pbDatosLegen6, "ListaLegendarios7" => :pbDatosLegen7,
               "ListaLegendarios8" => :pbDatosLegen8, "ListaLegendarios9" => :pbDatosLegen9 }

    # The open sheet's painted lines, collected from its two draw calls; nil while no sheet is open.
    @pending = nil

    def self.sheet_on; @pending = []; end
    def self.sheet_off; @pending = nil; end

    def self.note(text)
      return if @pending.nil?
      t = PokeAccess.clean(text.to_s)
      @pending.push(t) unless t.empty?
    rescue StandardError
      nil
    end

    # Speaks each painted batch once (the sheet paints everything, then blocks in its loop).
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
  # A sheet closes back onto its list, which then says its focused entry again.
  PokeAccess::AwakeningCompendium::SHEETS.each do |cname, meth|
    around(cname, meth, :optional => true) do |s, nxt, _a|
      PokeAccess::AwakeningCompendium.sheet_on
      begin
        nxt.call
      ensure
        PokeAccess::AwakeningCompendium.sheet_off
        PokeAccess::Cursor.reset(s, :awk_comp)
      end
    end
  end
  kernel("pbDrawTextPositions", :before) { |args, _r| PokeAccess::AwakeningCompendium.note_positions(args[1]) }
  kernel("drawTextEx", :before) { |args, _r| PokeAccess::AwakeningCompendium.note(args[5]) }
  poll_each_frame { PokeAccess::AwakeningCompendium.sheet_poll }
  # carteles (the "more information" panel, two battle tutorials) paints args[2] outside the captured calls.
  kernel("carteles", :before) { |args, _r| PokeAccess.speak_clean(args[2].to_s, true) }
end
