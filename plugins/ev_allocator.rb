# The EV allocator of the Level Based Mixed EV System: a mode of the summary's stats page. The focused stat
# and the number being changed are locals of pbEVAllocation's loop, but the plugin mirrors the cursor onto
# the selector sprite's index and raises $evalloc while the mode is up, so the reader polls from pbUpdate
# and says nothing the rest of the time. The cursor walks the page's six rows in both modes; the mixed one
# paints and edits Attack on the Sp. Atk row as well, which is what its fourth entry says.
module PokeAccess
  module EVAllocator
    FULL = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED] unless const_defined?(:FULL)
    MIXED = [:HP, :ATTACK, :DEFENSE, :ATTACK, :SPECIAL_DEFENSE, :SPEED] unless const_defined?(:MIXED)

    # The stat list this game is playing with.
    def self.stats
      (::Settings::PURIST_MODE rescue false) ? FULL : MIXED
    rescue StandardError
      MIXED
    end

    # The focused stat and its current effort value, while the allocator is up.
    def self.poll(scene)
      return unless (defined?($evalloc) && $evalloc)
      idx = (PokeAccess.sprite(scene, "EVsel").index rescue nil)
      stat = idx ? stats[idx.to_i] : nil
      return unless stat
      pk = PokeAccess.ivar(scene, :@pokemon)
      ev = (pk.ev[stat] rescue nil)
      return if ev.nil?
      return unless PokeAccess::Cursor.changed?(scene, :ev_alloc, [idx, ev])
      PokeAccess.speak(PokeAccess::I18n.t(:ev_row, :stat => PokeAccess::Data.stat_name(stat), :n => ev), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonSummary_Scene", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::EVAllocator.poll(scene)
end

# The plugin also brings a modal panel of its own, pbFullAbilityWindow: the FULL text of an ability or a move,
# which the summary shows on demand because its own box only has room for a line of it. Three screens raise
# it -- the stats page, the move manager and Enhanced UI's page -- and it blocks like every panel of its
# shape, so it is read on the way in.
PokeAccess::ModalPanel.watch("pbFullAbilityWindow")
