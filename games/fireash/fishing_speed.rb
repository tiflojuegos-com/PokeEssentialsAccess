# Fire Ash's fishing drops the game to normal speed while the line is out and restores it after; the speed
# announcer stays quiet through pbFishing, since the player pressed no key.
PokeAccess::Game.define("fireash") do
  kernel("pbFishing", :around) do |_args, nxt|
    PokeAccess::Turbo.quietly { nxt.call }
  end
end
