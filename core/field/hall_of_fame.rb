module PokeAccess
  # Hall of fame entry sequence, which draws team/banner text directly (not pbMessage), so it was silent.
  # gen-6 (HallOfFameScene) draws each member via writePokemonData and a banner via writeWelcome; modern
  # (HallOfFame_Scene) is pure sprite animation, so its team is read from the party on entry.
  module HallOfFame
    # The spoken hall-of-fame line for a member: nickname, species and level (or "egg").
    def self.member_text(pk)
      return nil unless pk
      return PokeAccess::I18n.t(:hof_egg) if (pk.egg? rescue (pk.isEgg? rescue false))
      nm = pk.name.to_s
      sp = PokeAccess::Data.species_name(pk.species)
      who = (sp && !sp.to_s.empty? && sp.to_s != nm) ? "#{nm}, #{sp}" : nm
      lvl = (pk.level rescue nil)
      lvl ? PokeAccess::I18n.t(:hof_member, :who => who, :level => lvl) : who
    rescue StandardError
      nil
    end
  end
end

# gen-6: welcome banner and each team member as they are drawn.
PokeAccess::Hooks.after_hook("HallOfFameScene", :writeWelcome) do |_s, _r, _a|
  PokeAccess.speak(PokeAccess::I18n.t(:hof_welcome), false)
end
# Read by CAPTURE: the panel paints dex number, name with its sex symbol, level, trainer ID and -- only
# in the PC viewer, where args[1] carries the record number -- the hall header, all words the per-language
# builds swap. The viewer path interrupts (browsing redraws member by member); the entry animation queues.
# Composing off the pokemon is the fallback for a copy that painted nothing.
PokeAccess::Hooks.around_hook("HallOfFameScene", :writePokemonData) do |_s, nxt, args|
  PokeAccess::PaintCapture.arm(:hof_panel)
  begin
    nxt.call
  ensure
    t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:hof_panel))
    t = PokeAccess::HallOfFame.member_text(args[0]).to_s if t.empty?
    pc_view = args[1].is_a?(Integer) && args[1] > -1
    PokeAccess.speak_clean(t, pc_view) unless t.strip.empty?
  end
end

# modern (HallOfFame_Scene): the welcome on entry, and the team only where there is no per-member read.
#
# The entry animation calls writePokemonData member by member, and the hook below speaks each one
# INTERRUPTING -- so reading the whole team here as well meant the long queued line was cut mid-word a few
# frames later. Where the scene has that method, the animation's own pass is the read; where it does not,
# this is the only one there is.
PokeAccess::Hooks.read_on_open("HallOfFame_Scene", :pbStartSceneEntry) do |s|
  if (s.respond_to?(:writePokemonData) rescue false)
    PokeAccess::I18n.t(:hof_welcome)
  else
    party = (PokeAccess::Engine.player.party rescue nil)
    names = party.is_a?(Array) ? party.compact.map { |pk| PokeAccess::HallOfFame.member_text(pk) }.compact : []
    names.empty? ? nil : "#{PokeAccess::I18n.t(:hof_welcome)}. #{names.join('. ')}"
  end
end

# modern (HallOfFame_Scene): the PC viewer of past records (pbStartScenePC) DOES draw each member via
# writePokemonData as you browse, so read the focused member there, interrupting on change. Deduped per
# scene by OBJECT IDENTITY (object_id as the Cursor key -- two team members may compare == but must both
# read), so a redraw of the same pokemon is silent.
PokeAccess::Hooks.after_hook("HallOfFame_Scene", :writePokemonData) do |scene, _r, args|
  pk = args[0]
  next unless pk
  next unless PokeAccess::Cursor.changed?(scene, :hof_pk, pk.object_id)
  t = PokeAccess::HallOfFame.member_text(pk)
  PokeAccess.speak(t, true) if t && !t.to_s.empty?
end
