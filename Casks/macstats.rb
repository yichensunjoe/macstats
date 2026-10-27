cask "macstats" do
  version :latest
  sha256 :no_check

  url "https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip"
  name "MacStats Panel"
  desc "Desktop panel for CPU, memory, GPU, energy, disk and network"
  homepage "https://github.com/yichensunjoe/macstats"

  app "MacStats.app"

  caveats <<~EOS
    MacStats is signed with an Apple Development certificate and is not notarized.
    If macOS blocks the first launch (the dialog only offers Done / Move to Trash),
    allow it in System Settings > Privacy & Security > Open Anyway, or run:
      xattr -dr com.apple.quarantine "/Applications/MacStats.app"
  EOS
end
