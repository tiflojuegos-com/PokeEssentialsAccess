# v22 Pokedex main list (Essentials v22: UI::PokedexVisuals). The species list is a passive
# UI::PokedexVisualsList; the focused species id is exposed as visuals.species, read here on the screen's
# cursor callback as "name, caught/seen" (or unknown for an unseen entry). The "choose a Dex" screen
# (UI::PokedexDexes) uses an active Window_CommandPokemon of dex names, already read by the generic reader.
PokeAccess::V22.on_nav("UI::PokedexVisuals") do |vis|
  sp = (vis.species rescue nil)
  if sp
    dex = (PokeAccess::Engine.player.pokedex rescue nil)
    name = (GameData::Species.get(sp).name rescue sp.to_s)
    if (dex && dex.owned?(sp) rescue false)
      name + ", " + PokeAccess::I18n.t(:dex_caught)
    elsif (dex && dex.seen?(sp) rescue false)
      name + ", " + PokeAccess::I18n.t(:dex_seen)
    else
      PokeAccess::I18n.t(:dex_unknown)
    end
  end
end

module PokeAccess
  # v22 Pokedex entry detail (UI::PokedexEntryVisuals). @page is :info/:area/:forms (changed by
  # go_to_next_page / go_to_previous_page); @species / @species_data is the shown species (set_dex_index
  # changes it with up/down); owned? gates the detail. Content reuses the pdx_* strings.
  module PokedexEntryV22
    # The spoken text for the focused page of the focused species.
    def self.body(vis)
      data = PokeAccess.ivar(vis, :@species_data)
      sp   = PokeAccess.ivar(vis, :@species)
      return nil unless data || sp
      name = (data ? (data.name rescue sp.to_s) : (GameData::Species.get(sp).name rescue sp.to_s))
      case PokeAccess.ivar(vis, :@page)
      when :area then PokeAccess::I18n.t(:pdx_zone, :name => name)
      when :forms
        fn = (data.form_name rescue nil)
        (fn && !fn.to_s.empty?) ? PokeAccess::I18n.t(:pdx_form, :name => name, :f => fn) : PokeAccess::I18n.t(:pdx_forms, :name => name)
      else info_text(vis, name, data)
      end
    rescue StandardError
      nil
    end

    # The info page: dex number, name, and (if owned) category, height, weight and the entry text.
    def self.info_text(vis, name, data)
      owned = (vis.send(:owned_species?) rescue (vis.send(:owned?) rescue false))
      num   = dex_number(vis)
      parts = [num ? PokeAccess::I18n.t(:pdx_number, :n => num, :name => name) : name]
      if owned && data
        cat = (data.category rescue nil); parts.push(PokeAccess::I18n.t(:pdx_category, :cat => cat)) if cat && !cat.to_s.empty?
        h = (data.height rescue 0).to_i;  parts.push(PokeAccess::I18n.t(:pdx_height, :h => PokeAccess::Pokedex.fmt_dec(h))) if h > 0
        w = (data.weight rescue 0).to_i;  parts.push(PokeAccess::I18n.t(:pdx_weight, :w => PokeAccess::Pokedex.fmt_dec(w))) if w > 0
        desc = (data.pokedex_entry rescue nil); parts.push(desc.to_s) if desc && !desc.to_s.empty?
      else
        parts.push(PokeAccess::I18n.t(:pdx_not_caught))
      end
      parts.join(". ")
    end

    # The regional dex number shown for the current entry, or nil.
    def self.dex_number(vis)
      dex = PokeAccess.ivar(vis, :@dex)
      i   = (vis.index rescue nil)
      return nil unless dex.is_a?(Array) && i && dex[i]
      n = dex[i].is_a?(Array) ? dex[i][0] : nil
      (n && n > 0) ? n : nil
    end

    # Speaks the focused page, deduped by [page, species index] so an in-place redraw stays silent.
    def self.speak(vis)
      key = [PokeAccess.ivar(vis, :@page), (vis.index rescue nil)]
      PokeAccess::Cursor.announce(vis, :dex_page, key) { body(vis) }
    rescue StandardError
      nil
    end
  end
end

if PokeAccess::Engine.has?("UI::PokedexEntryVisuals")
  [:go_to_next_page, :go_to_previous_page, :set_dex_index, :set_species].each do |m|
    PokeAccess::Hooks.after_hook("UI::PokedexEntryVisuals", m) do |vis, _ret, _args|
      PokeAccess::PokedexEntryV22.speak(vis)
    end
  end
end
