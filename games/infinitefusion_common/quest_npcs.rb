# The quest givers both games tag questNPC("<quest id>") in the editor, alone or after another name (Hoenn's rival on
# route 104 is HOENN_RIVAL questNPC(...)): the tag is a placeholder, as EV### is, so it is dropped from the event's own
# name; one left with nothing else is named as any unnamed character, and a name a puzzle declares still comes first.
module PokeAccess
  module IFQuestNpcs
    # The editor's quest tag, however its id is quoted or spaced.
    TAG = /questNPC\([^)]*\)/
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::Locator", :own_name) do |_mod, original, _args|
    original.call.to_s.gsub(PokeAccess::IFQuestNpcs::TAG, " ").strip.gsub(/\s{2,}/, " ")
  end
  override("PokeAccess::Locator", :placeholder_name?) do |_mod, original, args|
    args[0].to_s =~ /\A\s*#{PokeAccess::IFQuestNpcs::TAG.source}\s*\z/ ? true : original.call
  end
end
