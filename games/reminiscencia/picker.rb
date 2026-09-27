module PokeAccess
  # Reminiscencia's species picker (pbCommandsCustom): the panel beside the list (sex, moves, base stats), repainted
  # on each move, with the shiny star, the move types and the species' type icons its pictures add.
  module ReminPicker
    @active = false
    @panel = nil
    @rows = []
    @icons = []
    @species = nil

    # The move buttons' strip picture: each type is one 46-pixel band of it.
    MOVE_BUTTONS = /battleFightButtonsSummary/
    MOVE_BAND = 46

    # Runs the picker with the collector armed; returns what the picker returns.
    def self.watch
      @active = true
      @panel = nil
      @rows = []
      @icons = []
      @species = nil
      yield
    ensure
      @active = false
      @panel = nil
      @rows = []
      @icons = []
      @species = nil
    end

    # True while the picker runs.
    def self.active?; @active; end

    # Collects one pbDrawTextPositions burst while the picker is up, panel bitmaps only once they are known.
    def self.note(bitmap, rows)
      return unless @active && rows.is_a?(Array)
      return if @panel && !@panel.any? { |b| b.equal?(bitmap) }
      rows.each { |r| @rows.push([bitmap, r[0].to_s, r[1].to_i, r[2].to_i]) if r.is_a?(Array) }
    rescue StandardError
      nil
    end

    # Collects the pictures of a repaint while the picker is up (the shiny star, the move buttons).
    def self.note_icons(rows)
      return unless @active && rows.is_a?(Array)
      rows.each { |r| @icons.push([r[0].to_s, r[2].to_i, r[4].to_i]) if r.is_a?(Array) }
    rescue StandardError
      nil
    end

    # Keeps the species and form the picker's sprite is set to (setSpeciesBitmap), for the types the panel shows.
    def self.note_species(args)
      @species = [args[0], args[2]] if @active
    end

    # The type names the panel's icons show for the species on the sprite, or none: only the base form's, which the
    # species data holds, are said.
    def self.types
      return [] unless @species && (@species[1] || 0).to_i == 0
      (PokeAccess::Data.species_types(@species[0]) rescue nil) || []
    end

    # Whether the info key is the key the game's T answers to now (T, or wherever its extra was rebound), which opens
    # the bag in the picker.
    def self.info_on_game_t?
      game_t = (PokeAccess::Config.rebinds[:fast_travel] rescue nil) || 0x54
      (PokeAccess::Config.keys[:info] rescue nil) == game_t
    end

    # Once per frame: yields the info key to the game's T (not while its bag is open) and says the panel's burst,
    # kept for the info key, at the choose-a-Pokemon reading's full level.
    def self.flush
      return unless @active
      PokeAccess::Keys.yield_key!(:info) if info_on_game_t? && !(PokeAccess::ReminBag.watching? rescue false)
      @icons = [] if @rows.empty?
      return if @rows.empty?
      rows = @rows
      icons = @icons
      @rows = []
      @icons = []
      first = @panel.nil?
      @panel ||= rows.map { |b, _t, _x, _y| b }.uniq
      t = text(rows, icons, types)
      PokeAccess::Info.set_info(:text, PokeAccess.clean(t))
      PokeAccess.speak_clean(t, false) if PokeAccess::Verbosity.keep?(:pokemon_choice, :full)
      PokeAccess.speak(keys_line, false) if first && PokeAccess::Verbosity.hints?
    rescue StandardError
      nil
    end

    # The keys the picker paints under its panel, bag and back, as the player has them now.
    def self.keys_line
      kh = PokeAccess::KeyHints
      PokeAccess::I18n.t(:rem_picker_keys, :bag => kh.key(:fast_travel, "T"), :back => kh.key(:b, "X"))
    end

    # The type of the move button drawn beside a painted row, by its band of the strip, or nil.
    def self.move_type_at(icons, y)
      hit = (icons || []).detect { |path, iy, _sy| path =~ MOVE_BUTTONS && y - iy >= 0 && y - iy <= 12 }
      hit ? (PokeAccess::Data.type_name(hit[2] / MOVE_BAND) rescue nil) : nil
    end

    # The spoken panel for one burst: the sex sign, the shiny star, the types, then each painted line but the header,
    # cells left to right, a move with its button's type (a move the hard mode hides as "???" by its type alone).
    def self.text(rows, icons = [], type_names = [])
      signs = PokeAccess::Party::SIGNS
      sex = rows.map { |_b, t, _x, _y| t.strip }.select { |t| signs.include?(t) }
      head = sex.dup
      shiny = (icons || []).any? { |path, _y, _s| File.basename(path) == "shiny" }
      head.push(PokeAccess::Party.shiny_word(nil)) if shiny
      head.push(PokeAccess::I18n.t(:bt_type, :t => type_names.join(" "))) unless type_names.empty?
      lines = {}
      rows.each { |_b, t, x, y| (lines[y] ||= []).push([x, t]) unless signs.include?(t.strip) }
      ys = lines.keys.sort
      ys.shift
      said = ys.map do |y|
        line = lines[y].sort.map { |_x, t| t.strip }.select { |t| t =~ /[a-zA-Z0-9]/ }.join(" ")
        ty = move_type_at(icons, y)
        next line unless ty
        move = line.empty? ? PokeAccess::I18n.t(:rem_move_hidden) : line
        PokeAccess::I18n.t(:rem_move_typed, :move => move, :t => ty)
      end
      (head + said.reject { |l| l.empty? }).join(", ")
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbCommandsCustom", "hook_remi_picker", :around) do |_args, nxt|
  PokeAccess::ReminPicker.watch { nxt.call }
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "hook_remi_picker_rows", :before) do |args, _r|
  PokeAccess::ReminPicker.note(args[0], args[1])
end

PokeAccess::Hooks.wrap_kernel("pbDrawImagePositions", "hook_remi_picker_icons", :before) do |args, _r|
  PokeAccess::ReminPicker.note_icons(args[1])
end

PokeAccess::Hooks.before_hook("PokemonSprite", :setSpeciesBitmap, :optional => true) do |_sprite, args|
  PokeAccess::ReminPicker.note_species(args) if PokeAccess::ReminPicker.active?
end

PokeAccess::Keys.on_frame { PokeAccess::ReminPicker.flush }

PokeAccess::Verbosity.define_reading(:pokemon_choice, :vb_pokemon_choice, :vbh_pokemon_choice)
