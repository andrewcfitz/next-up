#!/usr/bin/env bash
# Writes Casks/next-up.rb for a release. Usage: Scripts/update-cask.sh 1.2.0 <sha256>
set -euo pipefail

version="${1:?version}"
sha256="${2:?sha256}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$repo_root/Casks"
cat > "$repo_root/Casks/next-up.rb" <<CASK
cask "next-up" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/andrewcfitz/next-up/releases/download/v#{version}/NextUp-#{version}.zip"
  name "Next Up"
  desc "Menu bar app and widget counting down to your next campground stay"
  homepage "https://github.com/andrewcfitz/next-up"

  depends_on macos: ">= :sequoia"

  app "NextUp.app"

  uninstall quit: "com.andrewcfitz.NextUp"

  zap trash: [
    "~/Library/Containers/com.andrewcfitz.NextUp",
    "~/Library/Containers/com.andrewcfitz.NextUp.Widget",
    "~/Library/Group Containers/8353VT99LA.com.andrewcfitz.NextUp",
  ]
end
CASK
echo "Wrote Casks/next-up.rb for $version"
