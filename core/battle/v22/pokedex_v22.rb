# v22 Pokedex list (UI::PokedexVisuals): the focused species as "name, caught/seen", the status from medium,
# "unknown" for an unseen one; the whole row goes to the info key.
PokeAccess::V22.on_nav("UI::PokedexVisuals") do |vis|
  sp = (vis.species rescue nil)
  if sp
    dex = (PokeAccess::Engine.player.pokedex rescue nil)
    name = (GameData::Species.get(sp).name rescue sp.to_s)
    if (dex && dex.owned?(sp) rescue false)
      PokeAccess::Verbosity.info_line(:dex_entry, [[name, :brief], [PokeAccess::I18n.t(:dex_caught), :medium]])
    elsif (dex && dex.seen?(sp) rescue false)
      PokeAccess::Verbosity.info_line(:dex_entry, [[name, :brief], [PokeAccess::I18n.t(:dex_seen), :medium]])
    else
      PokeAccess::Info.set_info(:text, PokeAccess::I18n.t(:dex_unknown))
      PokeAccess::I18n.t(:dex_unknown)
    end
  end
end

module PokeAccess
  # v22 Pokedex entry detail (UI::PokedexEntryVisuals): the page in @page (:info, :area, :forms) for the species
  # shown, read on each page or species change.
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
      parts = [[num ? PokeAccess::I18n.t(:pdx_number, :n => num, :name => name) : name, :brief]]
      if owned && data
        cat = (data.category rescue nil); parts.push([PokeAccess::I18n.t(:pdx_category, :cat => cat), :medium]) if cat && !cat.to_s.empty?
        h = (data.height rescue 0).to_i;  parts.push([PokeAccess::I18n.t(:pdx_height, :h => PokeAccess::Pokedex.fmt_dec(h), :n => h / 10.0), :full]) if h > 0
        w = (data.weight rescue 0).to_i;  parts.push([PokeAccess::I18n.t(:pdx_weight, :w => PokeAccess::Pokedex.fmt_dec(w), :n => w / 10.0), :full]) if w > 0
        desc = (data.pokedex_entry rescue nil); parts.push([desc.to_s, :full]) if desc && !desc.to_s.empty?
      else
        parts.push([PokeAccess::I18n.t(:pdx_not_caught), :brief])
      end
      PokeAccess::Verbosity.info_line(:dex_page, parts, ". ")
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
