# The v22 party screen (Essentials v22 UI::PartyVisuals). Its panels are passive sprites, so the only
# thing that voices the cursor is the set_index hook -- and the trailing button row is where it gets
# engine-specific: index MAX_PARTY_SIZE is Cancel normally but CONFIRM in choose-entry-order mode, where
# Cancel moves one further along. Confusing those two is the difference between confirming a Battle Tower
# team and throwing it away, and nothing pinned it. Runs only in the gamedata pass.

def party_v22_party
  [Poke.build(:name => "Bulba", :level => 12, :hp => 22, :totalhp => 22, :gender => 0),
   Poke.build(:name => "Fainty", :level => 9, :hp => 0, :totalhp => 30, :gender => 1)]
end

Suite.define("v22 party: the focused member is read with sex, level and HP, once per move") do
  vis = UI::PartyVisuals.new(party_v22_party)

  vis.set_index(0)
  eq "the focused member is read with name, sex, level and HP fraction", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Bulba",
                         :sex => " " + PokeAccess::I18n.t(:pk_male),
                         :level => 12, :hp => 22, :tot => 22)]

  SpeakCapture.clear
  vis.set_index(0)
  silent "re-asserting the same slot says nothing"

  SpeakCapture.clear
  vis.set_index(1)
  eq "the next member reads its own sex and carries the fainted flag", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pty_member, :name => "Fainty",
                         :sex => " " + PokeAccess::I18n.t(:pk_female),
                         :level => 9, :hp => 0, :tot => 30) + ", " + PokeAccess::I18n.t(:pk_fainted)]
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

# The button row. In the normal screen index MAX_PARTY_SIZE is the only button and it is Cancel; in
# choose-entry-order (multi-select) the engine inserts Confirm there and pushes Cancel to MAX+1. Same
# index, opposite meaning -- which is exactly why both are asserted here against each other.
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
