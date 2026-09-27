# Soulstones 2's multi-box picker (PokemonBox_Scene): thirty boxes and two set-switch buttons, read from each
# pbUpdateOverlay paint. With a box pinned the focused one is named from the data, as the name row shows the pin.
module PokeAccess
  module SS2BoxPicker
    # Row positions inside the focus batch, in the order the screen pushes them; the two set-switch buttons'
    # names follow it, in the order of their cursor positions.
    HOLDS = 0
    SET   = 2
    LABEL = 3
    NAME  = 4
    FOCUS_ROWS = 5

    # The cursor position of the first set-switch button, past the thirty boxes.
    BUTTONS = 30

    # The focused box, or the set-switch button the cursor is on; deduplicated on the box's data, not the line,
    # which adds the set and the pinned box only when they change.
    def self.say(scene)
      rows = PokeAccess::PaintCapture.take(:ss2_boxpick, :positions)
      return if rows.nil? || rows.length < FOCUS_ROWS
      idx = PokeAccess.ivar_i(scene, :@index)
      if idx >= BUTTONS
        line = rows[FOCUS_ROWS + idx - BUTTONS].to_s.strip
        return if line.empty? || !PokeAccess::Cursor.changed?(scene, :ss2_boxpick, [idx, line])
        return PokeAccess.speak_clean(line, true)
      end
      parts = box_parts(scene, rows)
      return if parts.nil?
      set = rows[SET].to_s.strip
      pin = pinned_box(scene) ? "#{rows[LABEL].to_s.strip} #{rows[NAME].to_s.strip}" : ""
      return unless PokeAccess::Cursor.changed?(scene, :ss2_boxpick, [idx, parts, set, pin])
      extra = []
      extra.push(set) if !set.empty? && PokeAccess::Cursor.changed?(scene, :ss2_boxset, set)
      extra.push(pin) if !pin.empty? && PokeAccess::Cursor.changed?(scene, :ss2_boxpin, pin)
      PokeAccess.speak_clean((parts + extra).join(", "), true)
    rescue StandardError
      nil
    end

    # A box: its name and count, and how many of it the running search tints.
    def self.box_parts(scene, rows)
      name = pinned_box(scene) ? focused_name(scene).to_s : rows[NAME].to_s.strip
      return nil if name.empty?
      holds = rows[HOLDS].to_s.strip
      parts = [name]
      parts.push(holds) unless holds.empty?
      hits = matches(scene)
      parts.push(PokeAccess::I18n.t(:ss2_box_matches, :n => hits)) if hits && hits > 0
      parts
    end

    # The pinned box, or nil when none is ([] is the screen's "no box").
    def self.pinned_box(scene)
      b = PokeAccess.ivar(scene, :@curbox)
      (b.nil? || b == []) ? nil : b
    end

    # The name of the box under the arrow, or nil past the thirty.
    def self.focused_name(scene)
      idx = PokeAccess.ivar_i(scene, :@index)
      set = PokeAccess.ivar(scene, :@curset)
      (idx <= 29 && set.is_a?(Array) && set[idx]) ? set[idx].name : nil
    end

    # How many Pokemon of the focused box the running search tints, by the screen's own tests; nil with no
    # search running.
    def self.matches(scene)
      type = PokeAccess.ivar(scene, :@sortType)
      species = PokeAccess.ivar(scene, :@sortSpecies)
      items = PokeAccess.ivar(scene, :@sortItems)
      shiny = PokeAccess.ivar(scene, :@sortShiny)
      return nil if type.nil? && species.nil? && items.nil? && shiny.nil?
      idx = PokeAccess.ivar_i(scene, :@index)
      set = PokeAccess.ivar(scene, :@curset)
      box = (idx <= 29 && set.is_a?(Array)) ? set[idx] : nil
      return 0 unless box
      n = 0
      box.length.times do |i|
        mon = box[i]
        next unless mon
        hit = (!type.nil? && (mon.types.include?(type) rescue false)) || (!species.nil? && mon.species == species) ||
              (!items.nil? && (mon.hasItem? rescue false) == items) || (!shiny.nil? && (mon.shiny? rescue false) == shiny)
        n += 1 if hit
      end
      n
    rescue StandardError
      nil
    end
  end
end

# The picker's search stays on $PokemonStorage after it closes, and the PC's box icons keep its tint until the picker
# opens again. The PokemonBoxIcon#update that runs is Storage System Utilities', which has no shiny branch.
module PokeAccess
  module SS2StorageTint
    # What the tint over a Pokemon's PC icon says, or nil when the running search leaves it untinted: red for
    # one without the searched type, green for the searched species, blue for an item held or not as searched.
    def self.phrase(pk)
      st = $PokemonStorage
      return nil if pk.nil? || st.nil?
      type = (st.sortType rescue nil)
      species = (st.sortSpecies rescue nil)
      items = (st.sortItems rescue nil)
      if !type.nil?
        return nil if ((pk.types rescue []) || []).include?(type)
        PokeAccess::I18n.t(:ss2_tint_not_type, :t => PokeAccess::Data.type_name(type))
      elsif !species.nil?
        (pk.species rescue nil) == species ? PokeAccess::I18n.t(:ss2_tint_match) : nil
      elsif !items.nil?
        ((pk.hasItem? rescue false) ? true : false) == items ? PokeAccess::I18n.t(:ss2_tint_match) : nil
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  around("PokemonBox_Scene", :pbUpdateOverlay, :optional => true) do |scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:ss2_boxpick)
    begin
      nxt.call
    ensure
      PokeAccess::SS2BoxPicker.say(scene)
    end
  end

  # The tint, said at every level right after the slot's name, level and place.
  override("PokeAccess::Party", :pc_details) do |_mod, original, args|
    tint = PokeAccess::SS2StorageTint.phrase(args[0])
    tint ? [[tint, :brief]] + original.call : original.call
  end

  # An egg's line has no details, so its tint goes at the end.
  override("PokeAccess::Party", :pc_line) do |_mod, original, args|
    line = original.call
    tint = PokeAccess::Summary.egg?(args[0]) ? PokeAccess::SS2StorageTint.phrase(args[0]) : nil
    tint ? "#{line}, #{tint}" : line
  end
end
