# v22 party screen (Essentials v22: UI::PartyVisuals). The panels are passive sprites driven by the screen,
# and the cursor moves through set_index -- called from both the normal and the choose-a-Pokemon navigate
# loops, whereas refresh_on_index_changed is skipped by the latter -- so set_index is the reliable hook.
# Party slots reuse Party.party_line (shared with the gen-6 reader); the trailing button row is engine-
# specific: index MAX_PARTY_SIZE is Cancel normally but Confirm in choose-entry-order (multi-select) mode,
# where Cancel sits at MAX_PARTY_SIZE+1 (005_UI_Party.rb initialize_cancel_button), so name those here.
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
