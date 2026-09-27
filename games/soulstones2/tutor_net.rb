# Soulstones 2's edited Tutor.net: the party grid, whose icon tints (pkmn_comp) say whether each member can learn
# the focused move; the generic reader reads the move list.
module PokeAccess
  module SS2TutorNet
    # The icon tint each party panel carries, as words. 0 is an egg or "no move focused", which the screen
    # draws the same and which says nothing either way.
    COMP = { 1 => :tut_can, 2 => :tut_cannot, 3 => :tut_knows }

    # The focused member as the grid draws it: its name and its tint, nothing else.
    def self.say_member(scene, index)
      party = PokeAccess.ivar(scene, :@party)
      pk = (party[index] rescue nil)
      line = pk ? PokeAccess.clean(pk.name.to_s) : PokeAccess::Party.party_line(party, index)
      return if line.nil? || line.to_s.empty?
      k = COMP[(PokeAccess.sprite(scene, "pokemon#{index}").pkmn_comp rescue nil)]
      line = "#{line}, #{PokeAccess::I18n.t(k)}" if k
      return unless PokeAccess::Cursor.changed?(scene, :ss2_tutor, [index, line])
      PokeAccess.speak(line, true)
    rescue StandardError
      nil
    end

    @browsing = false
    @said = nil

    # Runs the move list's loop, the only stretch where a repaint of the tints means the move under the
    # list changed.
    def self.browsing
      @browsing = true
      @said = nil
      yield
    ensure
      @browsing = false
    end

    # Who the move under the list suits, by the tints: who can learn it and who knows it, or that nobody can;
    # once per move and tint change, queued behind the move's name.
    def self.say_tints(scene)
      return unless @browsing
      party = PokeAccess.ivar(scene, :@party) || []
      comps = (0...party.length).map { |i| (PokeAccess.sprite(scene, "pokemon#{i}").pkmn_comp rescue nil) }
      list = PokeAccess.sprite(scene, "commands")
      key = [(list.index rescue nil), (list.commands[list.index] rescue nil), comps]
      return if key == @said
      @said = key
      parts = []
      can = names_with(party, comps, 1)
      knows = names_with(party, comps, 3)
      parts.push(PokeAccess::I18n.t(:tut_can_list, :names => can.join(", "))) unless can.empty?
      parts.push(PokeAccess::I18n.t(:tut_knows_list, :names => knows.join(", "))) unless knows.empty?
      parts.push(PokeAccess::I18n.t(:tut_nobody)) if parts.empty? && comps.include?(2)
      PokeAccess.speak(parts.join(". "), false) unless parts.empty?
    rescue StandardError
      nil
    end

    # The names of the members whose tint is comp.
    def self.names_with(party, comps, comp)
      out = []
      comps.each_with_index { |c, i| out.push(party[i].name.to_s) if c == comp && party[i] }
      out
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  # The grid cursor: pbChangeSelection returns the new index.
  after("PokemonTutorNet_Scene", :pbChangeSelection, :optional => true) do |scene, ret, _a|
    PokeAccess::SS2TutorNet.say_member(scene, ret)
  end

  # Entering the grid on the member chosen last time; before, since pbChoosePokemon is the grid's loop.
  before("PokemonTutorNet_Scene", :pbChoosePokemon, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_tutor)
    PokeAccess::SS2TutorNet.say_member(scene, (PokeAccess.ivar(scene, :@last_mon_index) || 0).to_i)
  end

  # The tints, said for each move the list lands on; the filter's repaint (moves handed in) is skipped, as the
  # reopened list says them.
  around("PokemonTutorNet_Scene", :pbScene, :optional => true) do |_s, nxt, _a|
    PokeAccess::SS2TutorNet.browsing { nxt.call }
  end

  after("PokemonTutorNet_Scene", :update_indicators, :optional => true) do |scene, _r, args|
    PokeAccess::SS2TutorNet.say_tints(scene) if args.empty?
  end

  # Dedicates the list as the filter refills it, since the reopened list reads its first move again.
  before("PokemonTutorNet_Scene", :pbSetCommands, :optional => true) do |scene, _a|
    PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
  end
end
