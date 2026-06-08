require "spec"
require "../spec_helper.cr"
require "../../src/fff/config.cr"
require "../../src/fff/directory_manager.cr"
require "../../src/fff/terminal.cr"
require "../../src/fff/ui_renderer.cr"
require "../../src/fff/input_mode.cr"
require "../../src/fff/file_manager.cr"

# ─────────────────────────────────────────────────────────────────────────────
class MockTerminal < FFF::Terminal
  @read_buffer = [] of String
  @key_index = 0
  @answer_queue = [] of String

  def initialize
    @width = 80
    @height = 24
    @reader = Term::Reader.new
    @prompt = Term::Prompt.new
    @read_buffer = [] of String
    @key_index = 0
    @answer_queue = [] of String
  end

  def queue_keys(*keys : String)
    @read_buffer.concat(keys)
  end

  def queue_answers(*answers : String)
    @answer_queue.concat(answers)
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

  def ask(message : String) : String
    !@answer_queue.empty? ? @answer_queue.shift : ""
  end

  def confirm_inline(message : String) : Bool
    !@answer_queue.empty? ? @answer_queue.shift == "y" : false
  end

  def prompt_inline(message : String, default : String? = nil) : String?
    !@answer_queue.empty? ? @answer_queue.shift : nil
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

  def keypress(message : String)
    nil
  end
end

module IntegrationHelper
  include SpecHelper
  extend self

  def create_test_file_manager(start_dir, picker_mode = false)
    mock_term = MockTerminal.new
    config = FFF::Config.new
    dir_manager = FFF::DirectoryManager.new(start_dir)
    dir_manager.read!

    fm = FFF::FileManager.new(config, start_dir, picker_mode, mock_term)
    fm.dir_manager = dir_manager
    fm.input_mode = FFF::InputMode.new(mock_term)
    {fm, mock_term}
  end
end

# ─────────────────────────────────────────────────────────────────────────────
describe FFF::FileManager do
  # ── Error display ──────────────────────────────────────────────────────────
  describe "show_error" do
    it "stores the message and a future expiry" do
      temp_dir = SpecHelper.create_temp_dir("ui_se")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.show_error("disk full")
        fm.error_msg.should eq("disk full")
        exp = fm.error_expires
        exp.should_not be_nil
        (exp.not_nil!.to_unix > Time.utc.to_unix).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "ignores nil and empty strings" do
      temp_dir = SpecHelper.create_temp_dir("ui_se_nil")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.show_error(nil)
        fm.show_error("")
        fm.error_msg.should be_nil
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Sort cycling ───────────────────────────────────────────────────────────
  describe "cycle_sort_mode" do
    it "cycles name → size → ctime → name" do
      temp_dir = SpecHelper.create_temp_dir("ui_csm")
      begin
        %w[a.txt b.txt c.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager

        dm.sort_mode.should eq(:name)
        fm.dir_manager.cycle_sort_mode; dm.sort_mode.should eq(:size)
        fm.dir_manager.cycle_sort_mode; dm.sort_mode.should eq(:time)
        fm.dir_manager.cycle_sort_mode; dm.sort_mode.should eq(:name)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "toggles sort reverse" do
      temp_dir = SpecHelper.create_temp_dir("ui_tsr")
      begin
        %w[a.txt b.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager

        dm.sort_reverse.should be_false
        fm.dir_manager.toggle_sort_reverse; dm.sort_reverse.should be_true
        fm.dir_manager.toggle_sort_reverse; dm.sort_reverse.should be_false
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Prev-state tracking for incremental redraw ─────────────────────────────
  describe "redraw — prev_scroll / prev_page_offset" do
    it "captures scroll state after each redraw" do
      temp_dir = SpecHelper.create_temp_dir("ui_ps")
      begin
        10.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)

        fm.prev_scroll.should eq(-1)
        fm.prev_page_offset.should eq(-1)

        fm.redraw
        fm.prev_scroll.should eq(0)
        fm.prev_page_offset.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Realistic directory structure ──────────────────────────────────────────
  describe "realistic directory structure" do
    it "reads all files and subdirectories from a realistic layout" do
      temp_dir = SpecHelper.create_temp_dir("ui_real")
      begin
        IntegrationHelper.create_realistic_test_structure(temp_dir)

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager

        dm.list.size.should be > 0
        dm.list.any? { |f| File.basename(f) == "document.txt" }.should be_true
        dm.list.any? { |f| File.basename(f) == "README.md" }.should be_true
        dm.list.any? { |f| File.basename(f) == "documents" }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── prompt_inline ESC cancels and returns nil ─────────────────────────────
  describe "prompt_inline ESC" do
    it "returns nil when queue is empty (simulates ESC cancel)" do
      fm, term = IntegrationHelper.create_test_file_manager("/tmp")
      result = term.prompt_inline("New file name:")
      result.should be_nil
    end
  end

  # ── confirm_inline Ctrl+C cancels ─────────────────────────────────────────
  describe "confirm_inline Ctrl+C" do
    it "returns false on Ctrl+C" do
      fm, term = IntegrationHelper.create_test_file_manager("/tmp")
      term.queue_answers("\u0003")
      result = term.confirm_inline("Proceed?")
      result.should be_false
    end
  end
end
