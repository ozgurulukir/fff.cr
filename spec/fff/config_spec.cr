require "spec"
require "../spec_helper.cr"
require "../../src/fff/config.cr"

describe FFF::Config do
  describe ".new" do
    it "creates default config" do
      config = FFF::Config.new
      config.key_bindings.should be_a(Hash(String, String))
    end
  end

  describe "loading from environment" do
    it "loads from environment variables" do
      SpecHelper.mock_env_vars({
        "FFF_KEY_UP"   => "w",
        "FFF_KEY_DOWN" => "s",
      }) do
        config = FFF::Config.new

        config.key_binding("up").should eq("w")
        config.key_binding("down").should eq("s")
      end
    end

    it "uses defaults when env vars are unset" do
      SpecHelper.mock_env_vars({
        "FFF_KEY_UP"   => "k",
        "FFF_KEY_DOWN" => "j",
      }) do
        config = FFF::Config.new

        config.key_binding("up").should eq("k")
        config.key_binding("down").should eq("j")
      end
    end
  end

  describe ".parse_ls_colors" do
    it "parses extension-based LS_COLORS" do
      SpecHelper.mock_ls_colors({
        "*.txt" => "01;33",
        "*.md"  => "01;34",
      }) do
        ls_colors = FFF::Config.parse_ls_colors(ENV["LS_COLORS"] || "")
        ls_colors["txt"].should eq(:yellow)
        ls_colors["md"].should eq(:blue)
      end
    end

    it "handles empty LS_COLORS" do
      ls_colors = FFF::Config.parse_ls_colors("")
      ls_colors.should be_empty
    end

    it "handles malformed LS_COLORS" do
      colors = "*.txt=01;33:invalid:*.md=01;34"
      ls_colors = FFF::Config.parse_ls_colors(colors)

      ls_colors["txt"].should eq(:yellow)
      ls_colors["md"].should eq(:blue)
      ls_colors.keys.should_not contain("invalid")
    end
  end

  describe ".key_binding" do
    it "returns configured key binding" do
      SpecHelper.mock_env_vars({
        "FFF_KEY_UP"   => "k",
        "FFF_KEY_DOWN" => "j",
      }) do
        config = FFF::Config.new

        config.key_binding("up").should eq("k")
        config.key_binding("down").should eq("j")
        config.key_binding("enter").should eq("l")
        config.key_binding("quit").should eq("q")
      end
    end

    it "returns empty string for unknown action" do
      config = FFF::Config.new
      config.key_binding("nonexistent").should eq("")
    end

    it "reads custom key bindings from environment" do
      SpecHelper.mock_env_vars({"FFF_KEY_UP" => "w"}) do
        config = FFF::Config.new
        config.key_binding("up").should eq("w")
      end
    end
  end
end
