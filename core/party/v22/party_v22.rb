# v22 party screen (UI::PartyVisuals), read on set_index, which both navigate loops call. Past the party, index
# MAX_PARTY_SIZE is Cancel, or Confirm in multi-select mode with Cancel after it.
PokeAccess::V22.on_nav("UI::PartyVisuals", :set_index) do |vis|
  idx   = vis.index
  party = vis.instance_variable_get(:@party)
  max   = (::Settings::MAX_PARTY_SIZE rescue 6)
  if idx.is_a?(Integer) && idx >= max
    multi = (vis.instance_variable_get(:@multi_select) rescue false)
    (multi && idx == max) ? PokeAccess::I18n.t(:pc_confirm) : PokeAccess::I18n.t(:pc_cancel)
  else
    PokeAccess::Party.party_line(party, idx)
  end
end
