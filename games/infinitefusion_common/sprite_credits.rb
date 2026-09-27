# The credit a finished fusion paints under its sprite (drawSpriteCredits: "Sprite by <artist>", none for a generated
# or local sprite), said after the congratulations the same screen shows with it.
PokeAccess::Game.define("infinitefusion_common") do
  kernel("drawSpriteCredits", :around) do |_args, nxt|
    PokeAccess::PaintCapture.arm(:if_sprite_credits)
    begin
      nxt.call
    ensure
      t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:if_sprite_credits) || [])
      PokeAccess.after_next_line(t) unless t.empty?
    end
  end
end
