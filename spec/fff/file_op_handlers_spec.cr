require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/file_op_handlers.cr"
require "../../src/fff/file_operations.cr"
require "../../src/fff/config.cr"
require "../../src/fff/terminal.cr"
require "../../src/fff/input_mode.cr"
require "../../src/fff/directory_manager.cr"

class MockFOTerminal < FFF::Terminal
  @answer_queue = [] of String

  def initialize
    @width = 80
    @height = 24
    @reader = Term::Reader.new
    @prompt = Term::Prompt.new
  end

  def queue_answers(*answers : String)
    @answer_queue.concat(answers)
  end

  def prompt_inline(message : String, default : String? = nil) : String?
    !@answer_queue.empty? ? @answer_queue.shift : default
  end

  def confirm_inline(message : String) : Bool
    !@answer_queue.empty? ? @answer_queue.shift == "y" : true
  end
end

class DummyFileOpHandler
  include FFF::FileOpHandlers

  property scroll : Int32
  property page_offset : Int32
  property marked : Set(String)
  property clipboard : Array(String)
  property clipboard_mode : Symbol
  property dir_manager : FFF::DirectoryManager
  property force_full_redraw : Bool
  property input_mode : FFF::InputMode

  def initialize(@dir_manager : FFF::DirectoryManager, @config : FFF::Config, @term : FFF::Terminal)
    @scroll = 0
    @page_offset = 0
    @marked = Set(String).new
    @clipboard = [] of String
    @clipboard_mode = :none
    @force_full_redraw = false
    @input_mode = FFF::InputMode.new(@term)
    @file_ops = FFF::FileOperations.new(@config, @term)
  end

  def show_error(msg : String)
  end

  def show_success(msg : String)
  end

  def show_info(msg : String)
  end

  def show_warning(msg : String)
  end

  def with_tui_restored(&)
    yield
  end

  def marked_or_current : Array(String)
    @marked.empty? ? [@dir_manager.list[@scroll]] : @marked.to_a
  end

  def cursor_down
    return if @dir_manager.list.empty?
    return if @scroll >= @dir_manager.list.size
    @scroll += 1
  end
end

describe FFF::FileOpHandlers do
  describe "#toggle_mark" do
    it "adds current item to marked set" do
      temp_dir = SpecHelper.create_temp_dir("test_toggle_mark")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = MockFOTerminal.new
        handler = DummyFileOpHandler.new(dir_manager, config, term)
        handler.scroll = 0

        handler.toggle_mark
        handler.marked.size.should eq(1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#toggle_mark_all" do
    it "marks all items when none are marked" do
      temp_dir = SpecHelper.create_temp_dir("test_mark_all")
      begin
        %w[a.txt b.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = MockFOTerminal.new
        handler = DummyFileOpHandler.new(dir_manager, config, term)

        handler.toggle_mark_all
        handler.marked.size.should eq(2)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#new_file" do
    it "creates a new file via inline prompt" do
      temp_dir = SpecHelper.create_temp_dir("test_foh_new_file")
      begin
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = MockFOTerminal.new
        term.queue_answers("new_file.txt")
        handler = DummyFileOpHandler.new(dir_manager, config, term)

        handler.new_file
        File.exists?(File.join(temp_dir, "new_file.txt")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#new_directory" do
    it "creates a new directory via inline prompt" do
      temp_dir = SpecHelper.create_temp_dir("test_foh_new_dir")
      begin
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = MockFOTerminal.new
        term.queue_answers("new_dir")
        handler = DummyFileOpHandler.new(dir_manager, config, term)

        handler.new_directory
        File.directory?(File.join(temp_dir, "new_dir")).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#yank_files" do
    it "copies current item into clipboard in :copy mode" do
      temp_dir = SpecHelper.create_temp_dir("test_foh_yank")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = MockFOTerminal.new
        handler = DummyFileOpHandler.new(dir_manager, config, term)
        handler.scroll = 0

        handler.yank_files
        handler.clipboard.size.should eq(1)
        handler.clipboard_mode.should eq(:copy)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#cut_files" do
    it "cuts current item into clipboard in :cut mode" do
      temp_dir = SpecHelper.create_temp_dir("test_foh_cut")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = MockFOTerminal.new
        handler = DummyFileOpHandler.new(dir_manager, config, term)
        handler.scroll = 0

        handler.cut_files
        handler.clipboard.size.should eq(1)
        handler.clipboard_mode.should eq(:cut)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#delete_files" do
    it "deletes marked files when confirmed" do
      temp_dir = SpecHelper.create_temp_dir("test_foh_delete")
      trash_dir = File.join(temp_dir, "trash")
      Dir.mkdir_p(trash_dir)
      begin
        src_file = SpecHelper.create_temp_file(temp_dir, "to_delete.txt", "bye")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!

        SpecHelper.mock_env_vars({"FFF_TRASH" => trash_dir}) do
          config = FFF::Config.new
          term = MockFOTerminal.new
          term.queue_answers("y")
          handler = DummyFileOpHandler.new(dir_manager, config, term)
          handler.marked = Set{src_file}

          handler.delete_files
          File.exists?(src_file).should be_false
          File.exists?(File.join(trash_dir, "to_delete.txt")).should be_true
        end
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end
end
