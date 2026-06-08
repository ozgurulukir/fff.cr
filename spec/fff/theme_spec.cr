require "json"
require "../../src/fff/theme.cr"
require "spec"

describe FFF::Theme do
  describe ".load" do
    it "loads default theme when name is nil and env is unset" do
      original = ENV["FFF_THEME"]?
      ENV.delete("FFF_THEME")
      theme = FFF::Theme.load(nil, nil)
      theme.should be_a(FFF::Theme)
      ENV["FFF_THEME"] = original if original
    end

    it "loads theme by name" do
      theme = FFF::Theme.load("dracula")
      theme.fg.should eq({248_u8, 248_u8, 242_u8})
    end

    it "falls back to default for unknown theme name" do
      theme = FFF::Theme.load("nonexistent-theme")
      theme.bg.should eq({30_u8, 30_u8, 46_u8})
    end

    it "uses FFF_THEME env var when name is nil" do
      SpecHelper.mock_env_vars({"FFF_THEME" => "nord"}) do
        theme = FFF::Theme.load(nil, nil)
        theme.fg.should eq({216_u8, 222_u8, 233_u8})
      end
    end
  end

  describe "ANSI rendering helpers" do
    it ".fg wraps text with ANSI escape codes" do
      result = FFF::Theme.fg("hello", {255_u8, 0_u8, 0_u8})
      result.should contain("\e[38;2;255;0;0m")
      result.should contain("hello")
      result.should contain("\e[0m")
    end

    it ".fg_bg wraps text with foreground and background ANSI codes" do
      result = FFF::Theme.fg_bg("test", {255_u8, 0_u8, 0_u8}, {0_u8, 0_u8, 255_u8})
      result.should contain("\e[38;2;255;0;0m")
      result.should contain("\e[48;2;0;0;255m")
      result.should contain("test")
    end

    it ".fg_bold includes bold attribute" do
      result = FFF::Theme.fg_bold("bold", {255_u8, 255_u8, 255_u8})
      result.should contain("\e[1m")
      result.should contain("\e[38;2;255;255;255m")
    end

    it ".fg_bg_bold_underline includes bold and underline" do
      result = FFF::Theme.fg_bg_bold_underline("x", {1_u8, 2_u8, 3_u8}, {4_u8, 5_u8, 6_u8})
      result.should contain("\e[1;4m")
      result.should contain("\e[38;2;1;2;3m")
      result.should contain("\e[48;2;4;5;6m")
    end

    it ".set_fg returns unclosed foreground escape" do
      result = FFF::Theme.set_fg({10_u8, 20_u8, 30_u8})
      result.should eq("\e[38;2;10;20;30m")
    end

    it ".set_fg_bg returns unclosed foreground and background escape" do
      result = FFF::Theme.set_fg_bg({1_u8, 2_u8, 3_u8}, {4_u8, 5_u8, 6_u8})
      result.should eq("\e[38;2;1;2;3m\e[48;2;4;5;6m")
    end

    it ".reset returns escape reset code" do
      FFF::Theme.reset.should eq("\e[0m")
    end
  end

  describe "built-in themes" do
    it "has a default theme" do
      FFF::Theme::BUILTIN_THEMES["default"]?.should_not be_nil
    end

    it "has catppuccin-mocha theme" do
      theme = FFF::Theme::BUILTIN_THEMES["catppuccin-mocha"]?
      theme.should_not be_nil
      theme.not_nil!.bg.should eq({30_u8, 30_u8, 46_u8})
    end

    it "has gruvbox-dark theme" do
      theme = FFF::Theme::BUILTIN_THEMES["gruvbox-dark"]?
      theme.should_not be_nil
      theme.not_nil!.bg.should eq({40_u8, 40_u8, 40_u8})
    end

    it "has nord theme" do
      theme = FFF::Theme::BUILTIN_THEMES["nord"]?
      theme.should_not be_nil
      theme.not_nil!.bg.should eq({46_u8, 52_u8, 64_u8})
    end

    it "has dracula theme" do
      theme = FFF::Theme::BUILTIN_THEMES["dracula"]?
      theme.should_not be_nil
      theme.not_nil!.bg.should eq({40_u8, 42_u8, 54_u8})
    end
  end
end
