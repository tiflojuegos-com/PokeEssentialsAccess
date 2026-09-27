# Load order for the generic game modules (no .rb), loaded after core. Edit to add/reorder.
# :plugins => :auto loads each plugin reader whose plugin's class the running game has, since this fallback profile
# cannot know which game it runs on.
{
  :modules => %w[
    constants
  ],
  :plugins => :auto
}
