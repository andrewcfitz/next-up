cask "next-up" do
  version "1.0.1"
  sha256 "8e67108ab373f5bef5e12140569d01b2629a79cf9cc888e9b6dc6e49a104034e"

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
