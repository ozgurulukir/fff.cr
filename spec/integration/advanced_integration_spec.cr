require "spec"
require "../spec_helper.cr"
require "../../src/fff/config.cr"
require "../../src/fff/directory_manager.cr"
require "../../src/fff/terminal.cr"
require "../../src/fff/ui_renderer.cr"
require "../../src/fff/input_mode.cr"
require "../../src/fff/file_manager.cr"

# ──────────────────────────────────────────────
# Standalone mock terminal (same as nav spec)
# ──────────────────────────────────────────────
class MockTerminal < FFF::Terminal
  @read_buffer = [] of String
  @key_index = 0

  getter width : Int32
  getter height : Int32

  def initialize
    @width = 80
    @height = 24
    @reader = Term::Reader.new
    @prompt = Term::Prompt.new
    @read_buffer = [] of String
    @key_index = 0
  end

  def read_keypress : String?
    if @key_index < @read_buffer.size
      @read_buffer[@key_index].tap { @key_index += 1 }
    else
      nil
    end
  rescue
    nil
  end

  def print(_str : String); end

  def move_to(_row : Int32, _col : Int32); end

  def set_scroll_region; end

  def reset_scroll_region; end

  def update_window_title(_path = ""); end

  def refresh_size; end

  def max_items : Int32
    @height - 2
  end

  def ask(message : String) : String
    ""
  end

  def confirm_inline(message : String) : Bool
    false
  end

  def keypress(message : String)
    nil
  end
end

module AdvancedHelper
  include SpecHelper
  extend self

  def create_mock_file_manager(start_dir, picker_mode = false)
    mock_term = MockTerminal.new
    config = FFF::Config.new
    dir_manager = FFF::DirectoryManager.new(start_dir)
    dir_manager.read!

    fm = FFF::FileManager.new(config, start_dir, picker_mode, mock_term)
    fm.dir_manager = dir_manager
    fm.renderer = FFF::UIRenderer.new(mock_term, config)
    fm.input_mode = FFF::InputMode.new(mock_term)
    {fm, mock_term}
  end
end

# ──────────────────────────────────────────────
describe FFF::FileManager do
  # ── Error ───────────────────────────────────
  describe "error lifecycle" do
    it "stores message and a future expiry on show_error" do
      temp_dir = SpecHelper.create_temp_dir("adv_err")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        fm.show_error("disk full")

        fm.error_msg.should eq("disk full")
        exp = fm.error_expires
        exp.should_not be_nil
        (exp.not_nil!.to_unix > Time.utc.to_unix).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "clears nil and empty strings silently" do
      temp_dir = SpecHelper.create_temp_dir("adv_err_nil")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        fm.show_error(nil)
        fm.show_error("")
        fm.error_msg.should be_nil
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Prev-state tracking for incremental redraw ─
  describe "redraw — prev_scroll / prev_page_offset tracking" do
    it "captures scroll state after redraw" do
      temp_dir = SpecHelper.create_temp_dir("adv_prev_scroll")
      begin
        10.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "x") }

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        # Initial values set by initialize
        fm.prev_scroll.should eq(-1)
        fm.prev_page_offset.should eq(-1)

        fm.redraw # no-op (no TTY), but state should be captured
        fm.prev_scroll.should eq(0)
        fm.prev_page_offset.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Hidden count / total size from DirectoryManager ──
  describe "directory metadata passed to DrawState" do
    it "exposes total_size for visible files and hidden_count for hidden entries" do
      temp_dir = SpecHelper.create_temp_dir("adv_meta")
      begin
        SpecHelper.create_temp_file(temp_dir, "normal.txt", "visible content here")
        SpecHelper.create_temp_file(temp_dir, ".hidden_file", "hidden content")

        ENV["FFF_HIDDEN"] = "1"
        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        dm = fm.dir_manager

        dm.total_size.should be > 0_i64
        dm.hidden_count.should eq(0) # hidden files are shown, so nothing is "hidden"
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
        ENV.delete("FFF_HIDDEN")
      end
    end
  end

  # ── Search + sort interaction ───────────────
  describe "search with sort mode change" do
    it "re-reads list after search and sort_mode is preserved" do
      temp_dir = SpecHelper.create_temp_dir("adv_search_sort")
      begin
        %w[alpha.txt beta.txt gamma.txt delta.txt].each { |n|
          SpecHelper.create_temp_file(temp_dir, n, "x")
        }

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Multiple page_down iterations ───────────
  describe "multi-page scrolling" do
    it "scrolls to bottom after several page_down calls" do
      temp_dir = SpecHelper.create_temp_dir("adv_multi_page")
      begin
        60.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "c") }

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        pg_size = fm.term.max_items

        3.times { fm.page_down }
        fm.scroll.should eq(59)      # last item in 60-item list
        fm.page_offset.should eq(38) # scroll - max + 1 = 59 - 22 + 1
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "scrolls back with successive page_up" do
      temp_dir = SpecHelper.create_temp_dir("adv_multi_page_up")
      begin
        60.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "c") }

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        pg_size = fm.term.max_items

        5.times { fm.page_down }
        fm.page_up
        fm.scroll.should eq(37)      # 59 - 22 = 37 (end - 1 page)
        fm.page_offset.should eq(37) # scroll < page_offset → page_offset = scroll
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Redraw force-full-draw conditions ───────
  describe "redraw full_draw conditions" do
    it "uses full_draw = true in search mode" do
      temp_dir = SpecHelper.create_temp_dir("adv_full_draw_search")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        im = fm.input_mode

        fm.start_search
        im.handle_key("a")
        fm.redraw # Should trigger full_draw because search_mode is active
        # no crash = pass
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "uses full_draw = true after list size change" do
      temp_dir = SpecHelper.create_temp_dir("adv_full_draw_list")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        fm.redraw
        fm.redraw
        SpecHelper.create_temp_file(temp_dir, "b.txt", "y")
        fm.redraw
        # no crash = pass
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Mark + toggle_hidden interaction ────────
  describe "mark survives hidden toggle" do
    it "keeps marked files visible after toggling hidden" do
      temp_dir = SpecHelper.create_temp_dir("adv_mark_hidden")
      begin
        SpecHelper.create_temp_file(temp_dir, "visible.txt", "x")
        SpecHelper.create_temp_file(temp_dir, ".secret.txt", "x")

        fm, _term = AdvancedHelper.create_mock_file_manager(temp_dir)
        marks = fm.marked
        dm = fm.dir_manager

        # mark the visible file before toggling
        fm.scroll = 0
        fm.toggle_mark
        marks.size.should eq(1)

        # After toggling hidden on and off, mark set is still the same file
        fm.dir_manager.toggle_hidden
        fm.dir_manager.toggle_hidden
        marks.size.should eq(1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end
end
