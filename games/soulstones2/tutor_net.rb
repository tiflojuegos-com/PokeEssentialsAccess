# Tutor.net, in the copy this game edited ("[Edited] Tutor.net"), hence the profile. The move list is read
# by the generic net; what nobody read is the party grid where the pokemon is chosen: above each panel an
# icon TINT says whether that member can learn the move (comp 1 can, 2 cannot, 3 knows it), and that tint
# is the whole point of the screen.
module PokeAccess
  module SS2TutorNet
    # The icon tint each party panel carries, as words. 0 is an egg or "no move focused", which the screen
    # draws the same and which says nothing either way.
    COMP = { 1 => :tut_can, 2 => :tut_cannot, 3 => :tut_knows }

    # The focused party member with what the screen says about it for this move.
    def self.say_member(scene, index)
      party = PokeAccess.ivar(scene, :@party)
      line = PokeAccess::Party.party_line(party, index)
      return if line.nil? || line.to_s.empty?
      k = COMP[(PokeAccess.sprite(scene, "pokemon#{index}").pkmn_comp rescue nil)]
      line = "#{line}, #{PokeAccess::I18n.t(k)}" if k
      return unless PokeAccess::Cursor.changed?(scene, :ss2_tutor, [index, line])
      PokeAccess.speak(line, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  # pbChangeSelection RETURNS the new index, the same shape the vanilla party scene has, so the return is
  # what says where the cursor landed.
  after("PokemonTutorNet_Scene", :pbChangeSelection, :optional => true) do |scene, ret, _a|
    PokeAccess::SS2TutorNet.say_member(scene, ret)
  end

  # Repainting the tints changes what every panel means without moving the cursor -- it happens when the
  # move under the list changes -- so the focused one is read again.
  after("PokemonTutorNet_Scene", :update_indicators, :optional => true) do |scene, _r, _a|
    PokeAccess::SS2TutorNet.say_member(scene, PokeAccess.ivar(scene, :@activecmd).to_i)
  end
end
