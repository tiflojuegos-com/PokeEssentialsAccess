# Load / continue screen. The save panel (player, badges, play time, location) is drawn text, not read;
# the option list is a command window already read. Announce the save summary when the screen opens.
# Opening this screen also forgets the current map: loading a save may land on the same map_id the player
# was already on, so without this the next announce_map_change (and the cache reset it triggers) would be
# suppressed by the stale map_id.
PokeAccess::Engine.scene_classes("PokemonLoadScene", "PokemonLoad_Scene").each do |cls|
  PokeAccess::Hooks.before_hook(cls, :pbStartScene) { |_s, _a| PokeAccess::Locator.forget_map rescue nil }
end

PokeAccess::Hooks.after_hook(PokeAccess::Engine.era_scene(:gen6, "PokemonLoadScene", "PokemonLoad_Scene"), :pbStartScene) do |_s, _r, args|
  show_continue = args[1]
  trainer = args[2]
  framecount = args[3]
  mapid = args[4]
  if show_continue && trainer
    parts = [PokeAccess::I18n.t(:load_save, :name => trainer.name)]
    nb = (trainer.numbadges rescue nil)
    parts.push(PokeAccess::I18n.t(:tr_badges, :n => nb)) if nb
    if framecount
      fps = (Graphics.frame_rate rescue 40)
      hm = PokeAccess::Util.playtime_parts((framecount / fps rescue 0))
      parts.push(PokeAccess::I18n.t(:load_play, :h => hm[0], :m => hm[1])) if hm
    end
    nm = (PokeAccess::Locator.map_name(mapid) rescue nil)
    parts.push(PokeAccess::I18n.t(:load_at, :map => nm)) if nm && !nm.to_s.empty?
    PokeAccess.speak(parts.join(", "), false)
  end
end

# GameData-era Essentials load panel (PokemonLoad_Scene): a different class/signature, and its panel also shows
# the Pokedex seen count; play time is already in seconds (stats.play_time).
PokeAccess::Hooks.after_hook(PokeAccess::Engine.era_scene(:gamedata, "PokemonLoad_Scene", "PokemonLoadScene"), :pbStartScene) do |_s, _r, args|
  show_continue = args[1]
  trainer = args[2]
  stats = args[3]
  mapid = args[4]
  if show_continue && trainer
    parts = [PokeAccess::I18n.t(:load_save, :name => trainer.name)]
    nb = (trainer.badge_count rescue nil)
    parts.push(PokeAccess::I18n.t(:tr_badges, :n => nb)) if nb
    seen = (trainer.pokedex.seen_count rescue nil)
    parts.push(PokeAccess::I18n.t(:load_dex, :n => seen)) if seen
    hm = PokeAccess::Util.playtime_parts((stats.play_time.to_i rescue nil))
    parts.push(PokeAccess::I18n.t(:load_play, :h => hm[0], :m => hm[1])) if hm
    nm = (PokeAccess::Locator.map_name(mapid) rescue nil)
    parts.push(PokeAccess::I18n.t(:load_at, :map => nm)) if nm && !nm.to_s.empty?
    PokeAccess.speak(parts.join(", "), false)
  end
end
