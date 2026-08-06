module PokeAccess
  # v22 Pokemon storage / PC (Essentials v22: UI::PokemonStorageVisuals). index is -1 box name, -2 party
  # button, -3 close, 0+ a slot; box is -1 (party panel) or a box number; @storage is the PokemonStorage.
  # The cursor moves via set_index, read here as the focused box pokemon, party member, or control, reusing
  # the pc_* strings shared with the gen-6 PC reader. (Held-Pokemon swap prompts are a later refinement.)
  module StorageV22
    # The spoken line for the focused storage cursor position. Negative indices are the box chrome: -1 box
    # name, -2 party button (Back when in the party panel, box -1), -3 close; >= 0 is a slot.
    def self.line(vis)
      idx     = (vis.index rescue nil)
      box     = (vis.box rescue nil)
      storage = PokeAccess.ivar(vis, :@storage)
      return nil if idx.nil?
      in_box = box.is_a?(Integer) && box >= 0
      held = ((vis.holding_pokemon? ? vis.pokemon : nil) rescue nil)
      case idx
      when -1 then PokeAccess::I18n.t(:pc_box, :name => (storage[box].name rescue ""))
      when -2 then in_box ? PokeAccess::I18n.t(:pc_team) : PokeAccess::I18n.t(:pc_back)
      when -3 then PokeAccess::I18n.t(:pc_close)
      else
        cols = PokeAccess::Party::BOX_COLUMNS
        pk  = in_box ? (storage[box, idx] rescue nil) : (storage.party[idx] rescue nil)
        pos = in_box ? PokeAccess::I18n.t(:pc_pos, :row => idx / cols + 1, :col => idx % cols + 1) : ""
        if held
          pk ? PokeAccess::I18n.t(:pc_swap, :name => pk.name, :held => held.name) + pos :
               PokeAccess::I18n.t(:pc_place, :held => held.name) + pos
        elsif pk
          PokeAccess::Info.set_info(:pokemon, pk)
          t = PokeAccess::I18n.t(:pc_slot, :name => pk.name, :level => pk.level)
          t += PokeAccess::Party.fainted_suffix(pk)
          t + pos
        else
          PokeAccess::I18n.t(:pc_empty) + pos
        end
      end
    rescue StandardError
      nil
    end

    # The line for a box CHANGE, which always LEADS with the box name. The engine pages boxes from any
    # cursor position, not only from the box-name row (update_interaction fires go_to_*_box on
    # QUICK_UP/QUICK_DOWN wherever the cursor is), so the slot line alone can come out byte-identical in
    # the new box -- two slots empty in both boxes read the same -- and the cursor dedup swallows it:
    # the player paged and heard nothing. Naming the box is also the answer to "which box am I in now?",
    # which the slot line never carried.
    def self.box_line(vis)
      here = line(vis)
      name = (PokeAccess.ivar(vis, :@storage)[(vis.box rescue nil)].name rescue nil)
      return here if name.nil? || name.to_s.empty?
      head = PokeAccess::I18n.t(:pc_box, :name => name)
      (here.nil? || here.to_s.empty? || here == head) ? head : "#{head}. #{here}"
    rescue StandardError
      nil
    end
  end
end

PokeAccess::V22.on_nav("UI::PokemonStorageVisuals", :set_index) { |vis| PokeAccess::StorageV22.line(vis) }
# Cycling boxes calls go_to_next_box/go_to_previous_box directly without touching @index, so set_index
# never fires: hook them too, through box_line so the new box is always named (see there).
# blocks-on-purpose: both hold a quarter-second slide animation, and @storage.currentBox is assigned AFTER
# it. Reading any earlier names the box the player just left.
PokeAccess::V22.on_nav("UI::PokemonStorageVisuals", :go_to_next_box) { |vis| PokeAccess::StorageV22.box_line(vis) }
PokeAccess::V22.on_nav("UI::PokemonStorageVisuals", :go_to_previous_box) { |vis| PokeAccess::StorageV22.box_line(vis) }
