# The grid variant of the Pokedex search, painted on the overlay with a bare cursor sprite; the redraws pass the
# cursor index:
#   pbRefreshDexSearch(params, index): the main grid; index 0..6 the filters (order, name, type, height, weight,
#     colour, shape), 7/8/9 the Clear / Search / Cancel buttons.
#   pbRefreshDexSearchParam(mode, cmds, sel, index): one filter's value picker; mode is the 0..6 field, cmds the
#     option list, a negative index a cell below the options (-1 the blank that clears the filter, or a height or
#     weight slider let go to its end, -2 OK, -3 Cancel).
module PokeAccess
  module DexSearch
    FIELDS = [:dxs_order, :dxs_name, :dxs_type, :dxs_height, :dxs_weight, :dxs_color, :dxs_shape]
    BUTTONS = { 7 => :dxs_clear, 8 => :dxs_search, 9 => :dxs_cancel }

    # The spoken label of one of the seven filters, or of a button row.
    def self.field_label(idx)
      return PokeAccess::I18n.t(BUTTONS[idx]) if BUTTONS[idx]
      key = FIELDS[idx]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The params slots each grid row paints (type, height and weight take two: two types, a range's min and max), and
    # the list each value comes from.
    SLOTS = [[0], [1], [2, 3], [4, 5], [6, 7], [8], [9]]
    LISTS = [:@orderCommands, :@nameCommands, :@typeCommands, :@heightCommands,
             :@weightCommands, :@colorCommands, :@shapeCommands]

    # The filters whose options the gen-6 lists keep as bare numbers: the types, and the shapes drawn as icons.
    TYPE = 2
    SHAPE = 6

    # The height and weight filters, with the limit the screen paints for an unset maximum (99.9 m, 999.9 kg): both
    # lists keep tenths, in every era.
    MEASURE_TOPS = { 3 => 999, 4 => 9999 }

    # A sub-screen's cells below its options: -1 the blank that clears the filter, -2 OK, -3 Cancel.
    BELOW = { -1 => :dxs_unset, -2 => :dxs_ok, -3 => :dxs_cancel }

    # The word for a sub-screen cell below the options: on a height or weight slider -1 lets that limit go (the
    # screen paints 0.0 or its top there), elsewhere the BELOW cell, Cancel from -3 down.
    def self.below_key(mode, i)
      return :dxs_no_limit if i == -1 && MEASURE_TOPS.has_key?(mode)
      BELOW[i] || :dxs_cancel
    end

    # A command-list entry as text: a GameData object's name (its to_s is a dump), else the raw value.
    def self.option_text(item)
      return nil if item.nil?
      n = (item.name rescue nil)
      return PokeAccess.clean(n.to_s) if n && !n.to_s.empty?
      PokeAccess.clean(item.to_s)
    end

    # A filter's option as the screen shows it: a height or weight as the metres or kilograms it paints, a type the
    # list keeps as a number by its name, a shape kept as a number by its place among the shapes, else the entry's text.
    # param mode the filter, as its FIELDS index
    def self.value_text(mode, list, i)
      item = list[i]
      return nil if item.nil?
      return measure(item) if MEASURE_TOPS.has_key?(mode) && item.is_a?(Numeric)
      return PokeAccess::Data.type_name(item) if mode == TYPE && item.is_a?(Integer)
      return PokeAccess::I18n.t(:list_pos, :i => i + 1, :n => list.length) if mode == SHAPE && item.is_a?(Integer)
      option_text(item)
    end

    # A height or weight in tenths as the screen paints it, one decimal.
    def self.measure(tenths)
      sprintf("%.1f", tenths / 10.0)
    end

    # A height or weight range as the two limits the screen paints: an unset minimum is 0.0, an unset maximum the
    # screen's top; the unset word when neither is set.
    def self.range_text(idx, list, lo, hi)
      return PokeAccess::I18n.t(:dxs_unset) if lo < 0 && hi < 0
      top = MEASURE_TOPS[idx]
      low = lo < 0 ? 0 : (lo >= list.length ? top : list[lo])
      high = hi < 0 ? top : (hi >= list.length ? 0 : list[hi])
      "#{measure(low)} - #{measure(high)}"
    end

    # A filter's current value in words, or the unset word (a slot of -1 means no filter); nil on bad input.
    def self.field_value(scene, idx, params)
      return nil unless params.is_a?(Array) && idx >= 0 && idx < FIELDS.length
      slots = SLOTS[idx]
      list = PokeAccess.ivar(scene, LISTS[idx])
      if MEASURE_TOPS.has_key?(idx) && list.is_a?(Array) && !list.empty?
        lo, hi = slots.map { |s| params[s].nil? ? -1 : params[s].to_i }
        return range_text(idx, list, lo, hi)
      end
      vals = slots.map do |s|
        v = params[s]
        next nil if v.nil? || v.to_i < 0
        (list.is_a?(Array) && list[v.to_i]) ? value_text(idx, list, v.to_i) : PokeAccess::I18n.t(:dxs_set)
      end
      vals = vals.compact.reject { |v| v.to_s.empty? }
      vals.empty? ? PokeAccess::I18n.t(:dxs_unset) : vals.join(" - ")
    rescue StandardError
      nil
    end

    # Voices the focused row of the main search grid: the filter and its current value, or the button.
    def self.main(scene, params, idx)
      i = idx.to_i
      label = field_label(i)
      return if label.nil?
      val = field_value(scene, i, params)
      PokeAccess::Cursor.announce(scene, :dex_search, [i, val], true) do
        val ? "#{label}, #{val}" : label
      end
    rescue StandardError
      nil
    end

    # Voices the focused option of a filter's sub-screen after the filter's name; a negative index is a cell below
    # the options (below_key): the blank that clears the filter or a slider's let-go limit, OK, or Cancel.
    def self.param(scene, mode, cmds, idx)
      @param = [scene, mode, cmds]
      i = idx.to_i
      title = FIELDS[mode.to_i] ? PokeAccess::I18n.t(FIELDS[mode.to_i]) : nil
      opt = if i < 0
              PokeAccess::I18n.t(below_key(mode.to_i, i))
            elsif cmds.is_a?(Array) && cmds[i]
              value_text(mode.to_i, cmds, i)
            end
      return if opt.nil? || opt.to_s.empty?
      PokeAccess::Cursor.announce(scene, :dex_search_param, [mode, i], true) do
        title ? "#{title}, #{opt}" : opt.to_s
      end
    rescue StandardError
      nil
    end

    # The cursor moved without a repaint: in mode -1, the main grid, the focus with the last repaint's params (edited
    # in place); in a filter's sub-screen, its option from the list its last repaint showed.
    def self.moved(sprite, idx)
      mode = PokeAccess.ivar_i(sprite, :@mode, -1)
      if mode == -1
        return unless @scene && @params
        return main(@scene, @params, idx)
      end
      return unless @param && @param[1].to_i == mode
      param(@param[0], mode, @param[2], idx)
    end
  end
end

PokeAccess::Hooks.after_hook("PokedexSearchSelectionSprite", :index=, :optional => true) do |sprite, _r, args|
  PokeAccess::DexSearch.moved(sprite, args[0])
end
PokeAccess::Hooks.after_hook("PokemonPokedex_Scene", :pbRefreshDexSearchParam) do |scene, _r, args|
  PokeAccess::DexSearch.param(scene, args[0], args[1], args[3])
end
