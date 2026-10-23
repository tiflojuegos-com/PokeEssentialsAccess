# Anil's copy of the Cable Club (plugins/cable_club.rb reads it) adds the key that leaves at once to the preview's
# countdown: said only while hints are, any other bracketed note kept.
PokeAccess::Game.define("anil") do
  override("PokeAccess::CableClub", :timer_text) do |_mod, _original, args|
    t = args[0].to_s
    PokeAccess::Verbosity.hints? ? t : t.sub(/\s*\(([^)]*)\)\s*\z/) { |m| $1 =~ PokeAccess::KeyHints::HINT ? "" : m }
  end
end
