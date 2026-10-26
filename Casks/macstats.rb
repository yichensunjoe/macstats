cask "macstats" do
  version :latest
  sha256 :no_check

  url "https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip"
  name "MacStats"
  desc "Desktop panel for CPU, memory, GPU, energy, disk and network"
  homepage "https://github.com/yichensunjoe/macstats"

  app "MacStats.app"

  caveats <<~EOS
    MacStats is signed with an Apple Development certificate and is not notarized.
    If macOS blocks the first launch, right-click the app in /Applications and choose Open.
  EOS
end
