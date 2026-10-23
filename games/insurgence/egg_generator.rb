module PokeAccess
  # Insurgence's Egg Generator, the GTS the load screen opens (Scene_GTS, then the wanted data with its IVs and moves
  # pages): rows of picture bars whose labels and values are painted on their bitmaps, and buttons that paint their
  # own name every frame. Each row is said as painted, the screen's title before the first.
  module InsurgenceEggGenerator
    # The rows each screen's cursor walks, by class.
    SCREENS = { "Scene_GTS" => 2, "GTSWantedData" => 9, "GTSWantedDataIVs" => 7, "GTSWantedDataMoves" => 5 }
    # What the wanted data paints for a species not chosen yet.
    UNSET = "????"
    @painting = nil

    # Runs the block keeping what it paints on scene's sprites, by sprite key; fresh starts the record over.
    def self.recording(scene, fresh)
      scene.instance_variable_set(:@access_egg_paint, {}) if fresh || PokeAccess.ivar(scene, :@access_egg_paint).nil?
      outer = @painting
      @painting = scene
      yield
    ensure
      @painting = outer
    end

    # Forgets the values painted beside scene's rows, which drawWantedData paints again.
    def self.values_cleared(scene)
      (PokeAccess.ivar(scene, :@access_egg_paint) || {}).delete_if { |key, _text| key =~ /\A\d+t\z/ }
    end

    # A paint on a sprite of the screen being recorded, kept under that sprite's key.
    def self.painted(bitmap, rows)
      scene = @painting
      return unless scene && rows.is_a?(Array)
      sprites = PokeAccess.ivar(scene, :@sprites) || {}
      key = sprites.keys.find { |k| (sprites[k].bitmap.equal?(bitmap) rescue false) }
      return unless key
      text = PokeAccess::PaintCapture.text(rows.map { |r| r.is_a?(Array) ? r[0] : nil }.compact)
      PokeAccess.ivar(scene, :@access_egg_paint)[key] = text unless text.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # Row idx of scene: a button by its name, a bar by its label and the value beside it; nil until painted.
    def self.row(scene, idx)
      sprite = (PokeAccess.ivar(scene, :@sprites) || {})[idx.to_s]
      button = defined?(::GTS_Button) && sprite.is_a?(::GTS_Button)
      return PokeAccess.clean(PokeAccess.ivar(sprite, :@name).to_s) if button
      paint = PokeAccess.ivar(scene, :@access_egg_paint) || {}
      label = paint[idx.to_s]
      return nil if label.nil?
      value = paint["#{idx}t"]
      return label if value.nil?
      value = PokeAccess::I18n.t(:dex_unknown) if value == UNSET
      PokeAccess::I18n.t(:ins_egg_row, :label => label, :value => value)
    end

    # The focused row with its place, after the screen's title the first time scene says one.
    def self.cell(scene, idx, cname)
      text = row(scene, idx)
      return nil if text.nil?
      text = PokeAccess::Verbosity.list_entry(text, idx + 1, SCREENS[cname])
      return text if PokeAccess.ivar(scene, :@access_egg_titled)
      scene.instance_variable_set(:@access_egg_titled, true)
      PokeAccess.sentences([(PokeAccess.ivar(scene, :@access_egg_paint) || {})["background"], text])
    end

    # Runs a command (a choice, a page opened and closed), then lets the focused row be said again unless it left.
    def self.commanded(scene, slot)
      yield
    ensure
      PokeAccess::Cursor.reset(scene, slot) unless PokeAccess.ivar(scene, :@exit)
    end
  end
end

PokeAccess::Game.define("insurgence") do
  %w[Scene_GTS GTSWantedData GTSWantedDataIVs GTSWantedDataMoves].each do |cname|
    slot = :"ins_egg_#{cname}"
    around(cname, :create_spriteset) { |s, nxt, _a| PokeAccess::InsurgenceEggGenerator.recording(s, true) { nxt.call } }
    around(cname, :do_command) { |s, nxt, _a| PokeAccess::InsurgenceEggGenerator.commanded(s, slot) { nxt.call } }
    focus_reader(cname, :slot => slot, :hook_container => true,
                 :key => lambda { |s, i| [i, PokeAccess::InsurgenceEggGenerator.row(s, i)] }) do |idx, scene|
      PokeAccess::InsurgenceEggGenerator.cell(scene, idx, cname)
    end
  end

  %w[GTSWantedData GTSWantedDataIVs GTSWantedDataMoves].each do |cname|
    around(cname, :drawWantedData) do |s, nxt, _a|
      PokeAccess::InsurgenceEggGenerator.recording(s, false) do
        PokeAccess::InsurgenceEggGenerator.values_cleared(s)
        nxt.call
      end
    end
  end

  kernel("pbDrawTextPositions") { |args, _r| PokeAccess::InsurgenceEggGenerator.painted(args[0], args[1]) }
end
