module PokeAccess
  # v22 PC storage (UI::PokemonStorageVisuals), read on set_index. index: -1 box name, -2 party button, -3
  # close, 0+ a slot; box: -1 the party panel, else a box number.
  module StorageV22
    # The line for the focused cursor position; -2 is Back in the party panel.
    def self.line(vis)
      idx     = (vis.index rescue nil)
      box     = (vis.box rescue nil)
      storage = PokeAccess.ivar(vis, :@storage)
      return nil if idx.nil?
      in_box = box.is_a?(Integer) && box >= 0
      held = ((vis.holding_pokemon? ? vis.pokemon : nil) rescue nil)
      case idx
      when -1 then PokeAccess::Party.box_row((storage[box].name rescue ""))
      when -2 then in_box ? PokeAccess::I18n.t(:pc_team) : PokeAccess::I18n.t(:pc_back)
      when -3 then PokeAccess::I18n.t(:pc_close)
      else
        cols = PokeAccess::Party.box_columns
        pk  = in_box ? (storage[box, idx] rescue nil) : (storage.party[idx] rescue nil)
        pos = in_box ? PokeAccess::I18n.t(:pc_pos, :row => idx / cols + 1, :col => idx % cols + 1) : ""
        where = PokeAccess::Verbosity.keep?(:pc_slot, :medium) ? pos : ""
        if held
          pk ? PokeAccess::I18n.t(:pc_swap, :name => pk.name, :held => held.name) + where :
               PokeAccess::I18n.t(:pc_place, :held => held.name) + pos
        elsif pk
          PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { PokeAccess::Party.pc_line(pk, pos) })
          PokeAccess::Party.pc_line(pk, pos)
        else
          PokeAccess::I18n.t(:pc_empty) + pos
        end
      end
    rescue StandardError
      nil
    end

    # The line after a box change, led by the box name (boxes page from any slot, whose line alone can repeat
    # the old box's); the box row, which starts with the name, is said as it is.
    def self.box_line(vis)
      here = line(vis)
      name = (PokeAccess.ivar(vis, :@storage)[(vis.box rescue nil)].name rescue nil)
      return here if name.nil? || name.to_s.empty?
      head = PokeAccess::I18n.t(:pc_box, :name => name)
      return head if here.nil? || here.to_s.empty?
      here.index(head) == 0 ? here : "#{head}. #{here}"
    rescue StandardError
      nil
    end
  end
end

PokeAccess::V22.on_nav("UI::PokemonStorageVisuals", :set_index) { |vis| PokeAccess::StorageV22.line(vis) }
# Paging boxes calls go_to_next_box/go_to_previous_box without set_index, so they are read through box_line.
# blocks-on-purpose: both hold a slide animation, and @storage.currentBox is set after it.
PokeAccess::V22.on_nav("UI::PokemonStorageVisuals", :go_to_next_box) { |vis| PokeAccess::StorageV22.box_line(vis) }
PokeAccess::V22.on_nav("UI::PokemonStorageVisuals", :go_to_previous_box) { |vis| PokeAccess::StorageV22.box_line(vis) }
