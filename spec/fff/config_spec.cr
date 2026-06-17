require "../../src/fff/format_utils.cr"
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

  describe "key_bindings" do
    it "returns hash mapping keys to actions" do
      config = FFF::Config.new
      bindings = config.key_bindings
      bindings["k"].should eq(config.key_up)
      bindings["j"].should eq(config.key_down)
    end

    it "reflects custom key bindings from environment" do
      SpecHelper.mock_env_vars({
        "FFF_KEY_UP"   => "w",
        "FFF_KEY_DOWN" => "s",
      }) do
        config = FFF::Config.new
        config.key_bindings["k"].should eq("w")
        config.key_bindings["j"].should eq("s")
      end
    end
  end

  describe "#parse_ls_colors" do
    it "parses extension-based LS_COLORS" do
      SpecHelper.mock_ls_colors({
        "*.txt" => "01;33",
        "*.md"  => "01;34",
      }) do
        config = FFF::Config.new
        ls_colors = config.ls_colors
        ls_colors["txt"].should eq(:yellow)
        ls_colors["md"].should eq(:blue)
      end
    end

    it "handles empty LS_COLORS" do
      original = ENV["LS_COLORS"]?
      ENV["LS_COLORS"] = ""
      config = FFF::Config.new
      ENV["LS_COLORS"] = original if original
      config.ls_colors.should be_empty
    end

    it "handles malformed LS_COLORS" do
      SpecHelper.mock_ls_colors({
        "*.txt"   => "01;33",
        "invalid" => "xxx",
        "*.md"    => "01;34",
      }) do
        config = FFF::Config.new
        ls_colors = config.ls_colors
        ls_colors["txt"].should eq(:yellow)
        ls_colors["md"].should eq(:blue)
        ls_colors.keys.should_not contain("invalid")
      end
    end
  end

  describe ".new" do
    it "falls back to defaults on invalid JSON in config file" do
      config_dir = File.join(FFF::HOME, ".config", "fff")
      config_path = File.join(config_dir, "config.json")
      original_content = File.exists?(config_path) ? File.read(config_path) : nil

      Dir.mkdir_p(config_dir)
      begin
        File.write(config_path, "{invalid json\n")
        config = FFF::Config.new
        config.key_quit.should eq("q")
        config.key_enter.should eq("l")
      ensure
        if original_content
          File.write(config_path, original_content)
        else
          File.delete(config_path) if File.exists?(config_path)
        end
      end
    end
  end
end
