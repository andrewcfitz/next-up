cask "next-up" do
  version "1.1.0"
  sha256 "a88c2e06c6d39250775cc712e095c4ece6c080b1b3168ba313ac000fb1dd5344"

  url "https://github.com/andrewcfitz/next-up/releases/download/v#{version}/NextUp-#{version}.zip"
  name "Next Up"
  desc "Menu bar app and widget counting down to your next campground stay"
  homepage "https://github.com/andrewcfitz/next-up"

  depends_on macos: ">= :sequoia"

  app "NextUp.app"

  uninstall quit: "biz.fitz.NextUp"

  zap trash: [
    "~/Library/Containers/biz.fitz.NextUp",
    "~/Library/Containers/biz.fitz.NextUp.Widget",
    "~/Library/Group Containers/8353VT99LA.biz.fitz.NextUp",
  ]
end
