module PokeAccess
  # Reminiscencia's species picker (pbCommandsCustom, opened by the Prana bubbles and by pbRentalsingle): a
  # command list of random species, read by the generic list reader, and beside it a panel repainted on
  # every cursor move (sex, four moves, base stats with the run's bonus) through pbDrawTextPositions onto
  # two overlay bitmaps. Which bitmaps ARE the panel is learned: the picker paints it once before its loop
  # starts, and only rows painted on those bitmaps are taken afterwards (the bag opened on T paints onto its
  # own). Rows are grouped by line, the header line dropped, the sex symbol said as a word and empty cells
  # skipped.
  module ReminPicker
    SEX = { "\xE2\x99\x82" => :pk_male, "\xE2\x99\x80" => :pk_female }
    @active = false
    @panel = nil
    @rows = []

    # Runs the picker with the collector armed; returns what the picker returns.
    def self.watch
      @active = true
      @panel = nil
      @rows = []
      yield
    ensure
      @active = false
      @panel = nil
      @rows = []
    end

    # Collects one pbDrawTextPositions burst while the picker is up, panel bitmaps only once they are known.
    def self.note(bitmap, rows)
      return unless @active && rows.is_a?(Array)
      return if @panel && !@panel.any? { |b| b.equal?(bitmap) }
      rows.each { |r| @rows.push([bitmap, r[0].to_s, r[1].to_i, r[2].to_i]) if r.is_a?(Array) }
    rescue StandardError
      nil
    end

    # The per-frame flush: the first burst fixes which bitmaps are the panel, and every burst is spoken once.
    def self.flush
      return if !@active || @rows.empty?
      rows = @rows
      @rows = []
      @panel ||= rows.map { |b, _t, _x, _y| b }.uniq
      t = text(rows)
      PokeAccess.speak_clean(t, false)
    rescue StandardError
      nil
    end

    # The spoken panel for one burst: sex first, then each painted line top to bottom, cells left to right.
    def self.text(rows)
      sex = rows.map { |_b, t, _x, _y| SEX[t] }.compact.map { |k| PokeAccess::I18n.t(k) }
      lines = {}
      rows.each { |_b, t, x, y| (lines[y] ||= []).push([x, t]) unless SEX.has_key?(t) }
      ys = lines.keys.sort
      ys.shift
      said = ys.map { |y| lines[y].sort.map { |_x, t| t.strip }.select { |t| t =~ /[a-zA-Z0-9]/ }.join(" ") }
      (sex + said.reject { |l| l.empty? }).join(", ")
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbCommandsCustom", "hook_remi_picker", :around) do |_args, nxt|
  PokeAccess::ReminPicker.watch { nxt.call }
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "hook_remi_picker_rows", :before) do |args, _r|
  PokeAccess::ReminPicker.note(args[0], args[1])
end

PokeAccess::Keys.on_frame { PokeAccess::ReminPicker.flush }
