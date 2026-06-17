require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/ui_renderer.cr"
require "../../src/fff/terminal.cr"
require "../../src/fff/config.cr"
require "../../src/fff/draw_state.cr"

describe FFF::UIRenderer do
  describe ".new" do
    it "creates renderer with terminal and config" do
      term = FFF::Terminal.new
      config = FFF::Config.new

      renderer = FFF::UIRenderer.new(term, config)
      renderer.should be_a(FFF::UIRenderer)
    end
  end

  describe "#redraw" do
    it "handles full redraw without crashing" do
      term = FFF::Terminal.new
      config = FFF::Config.new
      renderer = FFF::UIRenderer.new(term, config)

      state = FFF::DrawState.new(
        list: [] of String,
        scroll: 0,
        marked: Set(String).new,
        full: true,
        search_mode: false,
        search_term: "",
        loading: false,
        current_dir: "/test",
        clipboard_mode: :none,
        clipboard_size: 0,
        message: nil,
        rename_mode: false,
        rename_new_name: "",
        prev_scroll: 0,
        prev_page_offset: 0,
        page_offset: 0
      )

      renderer.redraw(state)
    end

    it "handles incremental redraw without crashing" do
      term = FFF::Terminal.new
      config = FFF::Config.new
      renderer = FFF::UIRenderer.new(term, config)

      state = FFF::DrawState.new(
        list: [] of String,
        scroll: 0,
        marked: Set(String).new,
        full: false,
        search_mode: false,
        search_term: "",
        loading: false,
        current_dir: "/test",
        clipboard_mode: :none,
        clipboard_size: 0,
        message: nil,
        rename_mode: false,
        rename_new_name: "",
        prev_scroll: 0,
        prev_page_offset: 0,
        page_offset: 0
      )

      renderer.redraw(state)
    end

    it "redraws with file list" do
      term = FFF::Terminal.new
      config = FFF::Config.new
      renderer = FFF::UIRenderer.new(term, config)

      state = FFF::DrawState.new(
        list: ["file1.txt", "file2.txt"],
        scroll: 0,
        marked: Set(String).new,
        full: true,
        search_mode: false,
        search_term: "",
        loading: false,
        current_dir: "/test",
        clipboard_mode: :none,
        clipboard_size: 0,
        message: nil,
        rename_mode: false,
        rename_new_name: "",
        prev_scroll: 0,
        prev_page_offset: 0,
        page_offset: 0
      )

      renderer.redraw(state)
    end
  end
end
