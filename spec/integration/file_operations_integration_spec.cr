require "spec"
require "../spec_helper.cr"
require "../../src/fff/config.cr"
require "../../src/fff/directory_manager.cr"
require "../../src/fff/terminal.cr"
require "../../src/fff/input_mode.cr"
require "../../src/fff/file_manager.cr"
require "../../src/fff/file_op_handlers.cr"
require "../../src/fff/file_operations.cr"

# ─────────────────────────────────────────────────────────────────────────────
# Reuse MockTerminal and IntegrationHelper from navigation_integration_spec.cr
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
  # ── Yank / paste ───────────────────────────────────────────────────────────
  describe "yank_files" do
    it "copies the current file into the clipboard in :copy mode" do
      temp_dir = SpecHelper.create_temp_dir("fo_yank")
      begin
        %w[a.txt b.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.scroll = 0
        fm.yank_files

        clip = fm.clipboard
        mode = fm.clipboard_mode
        clip.size.should eq(1)
        mode.should eq(:copy)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Delete files ──────────────────────────────────────────────────────────
  describe "delete_files" do
    it "sends marked files to trash" do
      temp_dir = SpecHelper.create_temp_dir("fo_df")
      begin
        path = SpecHelper.create_temp_file(temp_dir, "to_trash.txt", "bye")

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        trash_dir = File.join(ENV["HOME"], ".local", "share", "fff", "trash")

        fm.marked = Set{path}
        fm.scroll = 0
        term.queue_answers("y")
        fm.delete_files

        File.exists?(path).should be_false
        trash_contents = Dir.children(trash_dir)
        trash_contents.any? { |f| f.includes?("to_trash") }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
        if home = ENV["HOME"]?
          trash_dir = File.join(home, ".local", "share", "fff", "trash")
          FileUtils.rm_rf(trash_dir) if File.exists?(trash_dir)
        end
      end
    end

    it "returns nil when no files marked" do
      temp_dir = SpecHelper.create_temp_dir("fo_df_nomark")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.delete_files.should be_nil
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Paste files (copy mode) ───────────────────────────────────────────────
  describe "paste_files" do
    it "copies files from clipboard to current directory (copy mode)" do
      src_dir = SpecHelper.create_temp_dir("fo_pf_src")
      dst_dir = SpecHelper.create_temp_dir("fo_pf_dst")
      begin
        src_file = SpecHelper.create_temp_file(src_dir, "copy_me.txt", "content")

        fm, term = IntegrationHelper.create_test_file_manager(src_dir)
        fm.clipboard = [src_file]
        fm.clipboard_mode = :copy

        fm.dir_manager = FFF::DirectoryManager.new(dst_dir)
        fm.dir_manager.read!

        term.queue_answers("y")
        fm.paste_files

        dest_file = File.join(dst_dir, "copy_me.txt")
        File.exists?(dest_file).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(src_dir)
        SpecHelper.cleanup_temp_dir(dst_dir)
      end
    end
  end

  # ── Paste files (cut / move mode) ─────────────────────────────────────────
  describe "paste_files in cut mode" do
    it "moves files from clipboard to current directory" do
      src_dir = SpecHelper.create_temp_dir("fo_cut_src")
      dst_dir = SpecHelper.create_temp_dir("fo_cut_dst")
      begin
        src_file = SpecHelper.create_temp_file(src_dir, "move_me.txt", "content")

        fm, term = IntegrationHelper.create_test_file_manager(src_dir)
        fm.clipboard = [src_file]
        fm.clipboard_mode = :cut

        fm.dir_manager = FFF::DirectoryManager.new(dst_dir)
        fm.dir_manager.read!

        term.queue_answers("y")
        fm.paste_files

        File.exists?(src_file).should be_false
        dest_file = File.join(dst_dir, "move_me.txt")
        File.exists?(dest_file).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(src_dir)
        SpecHelper.cleanup_temp_dir(dst_dir)
      end
    end
  end

  # ── Rename ─────────────────────────────────────────────────────────────────
  describe "start_rename" do
    it "enters rename input mode" do
      temp_dir = SpecHelper.create_temp_dir("fo_sr")
      begin
        SpecHelper.create_temp_file(temp_dir, "original.txt", "content")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        input = fm.input_mode

        input.active.should be_false
        fm.start_rename
        input.active.should be_true
        input.mode.should eq(:rename)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Rename ESC restores list ──────────────────────────────────────────────
  describe "rename ESC restores original list" do
    it "cancels rename and restores full file list on ESC" do
      temp_dir = SpecHelper.create_temp_dir("fo_esc")
      begin
        %w[alpha.txt beta.txt gamma.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager
        dm.list.size.should eq(3)

        fm.scroll = 0
        fm.start_rename
        fm.input_mode.active.should be_true

        term.queue_keys("\e")
        fm.handle_input_mode("\e")

        fm.input_mode.active.should be_false
        dm.list.size.should eq(3)
        dm.list.any? { |f| File.basename(f) == "alpha.txt" }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Rename + Enter applies filesystem rename ────────────────────────────
  describe "rename + Enter applies filesystem rename" do
    it "renames file on disk when Enter is pressed with new name" do
      temp_dir = SpecHelper.create_temp_dir("fo_rn")
      begin
        path = SpecHelper.create_temp_file(temp_dir, "original.txt", "content")

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.scroll = 0
        fm.start_rename

        12.times { fm.input_mode.handle_key("\b") }
        fm.input_mode.text.should eq("")
        %w[r e n a m e d . t x t].each { |ch| fm.input_mode.handle_key(ch) }
        fm.input_mode.text.should eq("renamed.txt")

        fm.handle_rename_complete

        fm.input_mode.active.should be_false
        File.exists?(path).should be_false
        new_path = File.join(temp_dir, "renamed.txt")
        File.exists?(new_path).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Rename backspace during input ─────────────────────────────────────────
  describe "rename backspace" do
    it "deletes character before cursor during rename" do
      temp_dir = SpecHelper.create_temp_dir("fo_rbs")
      begin
        SpecHelper.create_temp_file(temp_dir, "original.txt", "content")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.scroll = 0
        fm.start_rename

        fm.input_mode.text.should eq("original.txt")
        fm.input_mode.cursor_pos.should eq(12)

        fm.input_mode.handle_key("\b")
        fm.input_mode.text.should eq("original.tx")
        fm.input_mode.cursor_pos.should eq(11)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "does not delete past start of text" do
      temp_dir = SpecHelper.create_temp_dir("fo_rbs2")
      begin
        SpecHelper.create_temp_file(temp_dir, "hi.txt", "x")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.scroll = 0
        fm.start_rename

        fm.input_mode.text.should eq("hi.txt")
        fm.input_mode.cursor_pos.should eq(6)

        6.times { fm.input_mode.handle_key("\b") }
        fm.input_mode.text.should eq("")
        fm.input_mode.cursor_pos.should eq(0)
        fm.input_mode.handle_key("\b")
        fm.input_mode.text.should eq("")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── New file / directory ───────────────────────────────────────────────────
  describe "new_directory / new_file" do
    it "creates a new subdirectory" do
      temp_dir = SpecHelper.create_temp_dir("fo_nd")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager
        dm.list.size.should eq(1)

        term.queue_answers("new_dir")
        fm.new_directory
        dm.list.any? { |p| File.basename(p) == "new_dir" }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "creates a new file" do
      temp_dir = SpecHelper.create_temp_dir("fo_nf")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager
        dm.list.size.should eq(1)

        term.queue_answers("new_file.txt")
        fm.new_file
        dm.list.any? { |p| File.basename(p) == "new_file.txt" }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Bulk rename ───────────────────────────────────────────────────────────
  describe "bulk_rename" do
    it "returns error when no files are marked" do
      temp_dir = SpecHelper.create_temp_dir("fo_br_empty")
      begin
        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        error = fm.file_ops.bulk_rename([] of String, "cat")
        error.should eq("No files marked")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Toggle executable (POSIX only) ────────────────────────────────────────
  describe "toggle_executable" do
    {% unless flag?(:windows) %}
      it "adds execute permission when confirmed" do
        temp_dir = SpecHelper.create_temp_dir("fo_te")
        begin
          path = SpecHelper.create_temp_file(temp_dir, "script.sh", "#!/bin/bash\necho hi")
          File.chmod(path, File.info(path).permissions & ~File::Permissions::OwnerExecute)

          fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
          term.queue_answers("y")
          fm.scroll = 0
          fm.toggle_executable

          (File.info(path).permissions.includes?(::File::Permissions::OwnerExecute)).should be_true
        ensure
          SpecHelper.cleanup_temp_dir(temp_dir)
        end
      end

      it "removes execute permission when toggled off" do
        temp_dir = SpecHelper.create_temp_dir("fo_te_rm")
        begin
          path = SpecHelper.create_temp_file(temp_dir, "script.sh", "#!/bin/bash\necho hi")
          File.chmod(path, File.info(path).permissions | File::Permissions::OwnerExecute)

          fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
          term.queue_answers("y")
          fm.scroll = 0
          fm.toggle_executable # remove execute

          (File.info(path).permissions.includes?(::File::Permissions::OwnerExecute)).should be_false
        ensure
          SpecHelper.cleanup_temp_dir(temp_dir)
        end
      end
    {% end %}
  end
end
