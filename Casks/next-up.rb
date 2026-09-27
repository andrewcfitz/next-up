cask "next-up" do
  version "1.0.0"
  sha256 "bcf7e2cc1341ba426312495b65ce3c9af82bcaa19757829e83c84fd34f5df511"

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
