module PokeAccess
  # Reminiscencia's party screen moves the member under the cursor to the lead with the 1 key (raw 0x31), sliding the
  # two cards and refreshing with the cursor left on the old lead; said as the new lead, then the focused member.
  module ReminPartyLead
    # Remembers who leads as the list takes a choice.
    def self.start(scene)
      party = PokeAccess.ivar(scene, :@party)
      scene.instance_variable_set(:@access_lead, party.is_a?(Array) ? party[0] : nil)
    end

    # After a refresh while the player chooses: when the lead is another Pokemon, says so and reads the member now
    # under the cursor.
    def self.refreshed(scene)
      party = PokeAccess.ivar(scene, :@party)
      return unless party.is_a?(Array) && party[0]
      last = PokeAccess.ivar(scene, :@access_lead)
      scene.instance_variable_set(:@access_lead, party[0])
      return if last.nil? || last.equal?(party[0])
      PokeAccess.speak(PokeAccess::I18n.t(:rem_party_lead, :name => party[0].name), true)
      PokeAccess::Party.announce_member(scene, party, PokeAccess.ivar(scene, :@activecmd))
    rescue StandardError
      nil
    end
  end
end

# Reminiscencia's party screen jumps to the PC on T (0x54), also the mod's info key: while the player chooses a
# member, the info key yields to the game unless it was rebound; elsewhere on the screen it stays the mod's. A
# refresh while choosing is the 1 key's swap with the lead.
PokeAccess::Game.define("reminiscencia") do
  around("PokemonScreen_Scene", :pbChoosePokemon, :optional => true) do |scene, nxt, _a|
    scene.instance_variable_set(:@access_choosing, true)
    PokeAccess::ReminPartyLead.start(scene)
    begin
      nxt.call
    ensure
      scene.instance_variable_set(:@access_choosing, false)
    end
  end
  after("PokemonScreen_Scene", :update, :optional => true) do |scene, _r, _a|
    next unless PokeAccess.ivar(scene, :@access_choosing)
    PokeAccess::Keys.yield_key!(:info) if (PokeAccess::Config.keys[:info] rescue nil) == 0x54
  end
  after("PokemonScreen_Scene", :pbRefresh, :optional => true) do |scene, _r, _a|
    PokeAccess::ReminPartyLead.refreshed(scene) if PokeAccess.ivar(scene, :@access_choosing)
  end
end
