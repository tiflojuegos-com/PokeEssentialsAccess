# The v22 party screen (UI::PartyVisuals), voiced only by the set_index hook: the members, and the trailing button,
# Cancel normally but Confirm in choose-entry-order mode (Cancel one further along).

def party_v22_party
  [Poke.build(:name => "Bulba", :level => 12, :hp => 22, :totalhp => 22, :gender => 0),
   Poke.build(:name => "Fainty", :level => 9, :hp => 0, :totalhp => 30, :gender => 1),
   Poke.build(:name => "Brilli", :level => 30, :hp => 50, :totalhp => 50, :gender => 0, :shiny => true)]
end

Suite.define("v22 party: the focused member is read with sex, level and HP, once per move") do
  vis = UI::PartyVisuals.new(party_v22_party)

  vis.set_index(0)
  eq "the focused member is read with name, sex, level and HP fraction", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Bulba",
                         :sex => " \xE2\x99\x82",
                         :level => 12, :hp => 22, :tot => 22)]

  SpeakCapture.clear
  vis.set_index(0)
  silent "re-asserting the same slot says nothing"

  SpeakCapture.clear
  vis.set_index(1)
  eq "the next member reads its own sex and carries the fainted flag", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Fainty",
                         :sex => " \xE2\x99\x80",
                         :level => 9, :hp => 0, :tot => 30) + ", " + PokeAccess::I18n.t(:pk_fainted)]

  SpeakCapture.clear
  vis.set_index(2)
  eq "a shiny says so, on the line the screen speaks", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Brilli",
                         :sex => " \xE2\x99\x82",
                         :level => 30, :hp => 50, :tot => 50) + ", " + PokeAccess::I18n.t(:pk_shiny)]
end

# The dedup is per screen instance, so a party screen opened again on the same slot must read it.
Suite.define("v22 party: reopening the party re-reads the slot the cursor is on") do
  party = party_v22_party
  first = UI::PartyVisuals.new(party)
  first.set_index(0)
  SpeakCapture.clear
  first.set_index(0)
  silent "the same screen on the same slot stays silent"

  SpeakCapture.clear
  UI::PartyVisuals.new(party).set_index(0)
  spoke_once "a reopened party screen reads that slot again", /Bulba/
end

Suite.define("v22 party: the trailing button is Cancel normally and Confirm in multi-select") do
  normal = UI::PartyVisuals.new(party_v22_party)
  normal.set_index(6)
  eq "in the normal screen the button after the last slot is Cancel", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_cancel)]

  SpeakCapture.clear
  multi = UI::PartyVisuals.new(party_v22_party, :choose_entry_order)
  multi.set_index(6)
  eq "in choose-entry-order that same index is Confirm", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_confirm)]

  SpeakCapture.clear
  multi.set_index(7)
  eq "and Cancel sits one further along", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_cancel)]
end
