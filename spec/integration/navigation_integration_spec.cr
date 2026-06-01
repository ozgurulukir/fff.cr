require "spec"
require "../spec_helper.cr"
require "../../src/fff/config.cr"
require "../../src/fff/directory_manager.cr"
require "../../src/fff/terminal.cr"
require "../../src/fff/ui_renderer.cr"
require "../../src/fff/input_mode.cr"
require "../../src/fff/file_manager.cr"

# ─────────────────────────────────────────────────────────────────────────────
# Minimal mock terminal — satisfies the FFF::Terminal contract for the parts
# that FileManager exercises in navigation tests, without opening a real TTY.
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

  # Queue keys to be returned by read_keypress (simulates user input).
  def queue_keys(*keys : String)
    @read_buffer.concat(keys)
  end

  # Queue answers for ask/confirm prompts.
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
    if !@answer_queue.empty?
      @answer_queue.shift
    else
      ""
    end
  end

  def confirm?(message : String) : Bool
    !@answer_queue.empty? ? @answer_queue.shift == "y" : false
  end

  def confirm_inline(message : String) : Bool
    !@answer_queue.empty? ? @answer_queue.shift == "y" : false
  end

  # Mock prompt_inline: consume from answer queue, return nil if empty (no TTY).
  def prompt_inline(message : String, default : String? = nil) : String?
    !@answer_queue.empty? ? @answer_queue.shift : nil
  end

  # Enqueue keys to be returned by read_keypress (simulates user input).
  def queue_keys(*keys : String)
    @read_buffer.concat(keys)
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

  # ── Silence all TTY / ANSI output ──────────────────────────────────────────
  def print(_str : String); end

  def move_to(_row : Int32, _col : Int32); end

  def clear_line; end

  def enter_tui; end

  def leave_tui; end

  def clear; end

  def clear_to_end; end

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

# ─────────────────────────────────────────────────────────────────────────────
# Test helpers
# ─────────────────────────────────────────────────────────────────────────────
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

  def create_file_manager_with_answers(start_dir, *answers)
    fm, term = create_test_file_manager(start_dir)
    answers.each { |a| term.queue_answers(a) }
    fm
  end

  def create_realistic_test_structure(base_dir)
    files = [
      {name: "document.txt", content: "This is a document file"},
      {name: "report.pdf", content: "PDF report content"},
      {name: "image.png", content: "PNG image content"},
      {name: "script.sh", content: "#!/bin/bash\necho 'hello world'"},
      {name: "data.json", content: %q|{"name": "test", "value": 42}|},
      {name: "README.md", content: "# README\nThis is a readme file"},
    ]

    dirs = %w[documents images scripts config]

    files.each { |fi| create_temp_file(base_dir, fi[:name], fi[:content]) }

    dirs.each do |dir_name|
      dir_path = File.join(base_dir, dir_name)
      Dir.mkdir_p(dir_path)

      case dir_name
      when "documents"
        create_temp_file(dir_path, "internal_doc.txt", "Internal document")
        create_temp_file(dir_path, "notes.txt", "Meeting notes")
      when "images"
        create_temp_file(dir_path, "photo1.jpg", "JPEG image")
        create_temp_file(dir_path, "logo.svg", "SVG logo")
      when "scripts"
        create_temp_file(dir_path, "backup.sh", "#!/bin/bash\necho 'backup script'")
        create_temp_file(dir_path, "deploy.sh", "#!/bin/bash\necho 'deploy script'")
      when "config"
        create_temp_file(dir_path, "settings.conf", "Configuration file")
        create_temp_file(dir_path, "env_vars", "Environment variables")
      end
    end

    create_temp_file(base_dir, ".hidden_file", "Hidden content")
    create_temp_file(base_dir, ".config", "Hidden config")

    source_file = File.join(base_dir, "document.txt")
    symlink_path = File.join(base_dir, "link_to_document")
    File.symlink("document.txt", symlink_path) if File.exists?(source_file)

    {base_dir, dirs}
  end
end

# ─────────────────────────────────────────────────────────────────────────────
describe FFF::FileManager do
  # ── Construction ───────────────────────────────────────────────────────────
  describe ".new" do
    it "initialises with the start directory" do
      temp_dir = SpecHelper.create_temp_dir("fm_new_dir")
      begin
        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager
        dm.current_dir.should eq(temp_dir)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "starts with scroll and page_offset at zero" do
      temp_dir = SpecHelper.create_temp_dir("fm_scroll_init")
      begin
        %w[a.txt b.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.scroll.should eq(0)
        fm.page_offset.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Cursor navigation ──────────────────────────────────────────────────────
  describe "cursor_down / cursor_up" do
    it "moves cursor down by one" do
      temp_dir = SpecHelper.create_temp_dir("fm_cd1")
      begin
        %w[a.txt b.txt c.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.cursor_down
        fm.scroll.should eq(1)
        fm.cursor_down
        fm.scroll.should eq(2)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "does not move cursor past the last item" do
      temp_dir = SpecHelper.create_temp_dir("fm_cd_max")
      begin
        %w[a.txt b.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        10.times { fm.cursor_down }
        fm.scroll.should eq(1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "does not move cursor below zero on cursor_up" do
      temp_dir = SpecHelper.create_temp_dir("fm_cu0")
      begin
        %w[a.txt b.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        10.times { fm.cursor_up }
        fm.scroll.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Page navigation ────────────────────────────────────────────────────────
  describe "page_down / page_up" do
    it "scrolls one screenful down and updates scroll and page_offset" do
      temp_dir = SpecHelper.create_temp_dir("fm_pd")
      begin
        60.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "c") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        pg_size = fm.term.max_items

        fm.page_down
        fm.scroll.should eq(pg_size)
        fm.page_offset.should be > 0 # scroll >= max → page_offset moves forward
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "scrolls one screenful up and resets page_offset toward zero" do
      temp_dir = SpecHelper.create_temp_dir("fm_pu")
      begin
        60.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "c") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        pg_size = fm.term.max_items

        pg_size.times { fm.cursor_down }
        fm.page_up
        fm.page_offset.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "does not move page_offset below zero" do
      temp_dir = SpecHelper.create_temp_dir("fm_pu0")
      begin
        5.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "c") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        5.times { fm.page_up }
        fm.page_offset.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── go_top / go_bottom ─────────────────────────────────────────────────────
  describe "go_top / go_bottom" do
    it "go_top resets scroll and page_offset to zero" do
      temp_dir = SpecHelper.create_temp_dir("fm_gt")
      begin
        10.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "c") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        5.times { fm.cursor_down }
        fm.go_top
        fm.scroll.should eq(0)
        fm.page_offset.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "go_bottom moves cursor to last item" do
      temp_dir = SpecHelper.create_temp_dir("fm_gb")
      begin
        10.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "c") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager

        fm.go_bottom
        fm.scroll.should eq(dm.list.size - 1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Directory traversal ────────────────────────────────────────────────────
  describe "go_parent" do
    it "changes current_dir to the parent directory" do
      temp_dir = SpecHelper.create_temp_dir("fm_gp")
      begin
        sub_dir = File.join(temp_dir, "subdir")
        Dir.mkdir(sub_dir)
        SpecHelper.create_temp_file(sub_dir, "child.txt", "x")

        fm, _term = IntegrationHelper.create_test_file_manager(sub_dir)
        fm.go_parent
        fm.dir_manager.current_dir.should eq(temp_dir)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "go_home" do
    it "changes current_dir to $HOME" do
      temp_dir = SpecHelper.create_temp_dir("fm_gh")
      begin
        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.go_home
        fm.dir_manager.current_dir.should eq(ENV["HOME"] || Dir.current)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Toggle hidden ──────────────────────────────────────────────────────────
  describe "toggle_hidden" do
    it "reveals dot-files on first toggle, hides on second" do
      temp_dir = SpecHelper.create_temp_dir("fm_th")
      begin
        SpecHelper.create_temp_file(temp_dir, "visible.txt", "x")
        SpecHelper.create_temp_file(temp_dir, ".invisible.txt", "x")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager

        initial = dm.list.size
        dm.list.none? { |f| File.basename(f).starts_with?(".") }.should be_true

        fm.dir_manager.toggle_hidden
        dm.list.any? { |f| File.basename(f).starts_with?(".") }.should be_true
        dm.list.size.should be > initial

        fm.dir_manager.toggle_hidden
        dm.list.size.should eq(initial)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Marking ────────────────────────────────────────────────────────────────
  describe "toggle_mark" do
    it "adds and removes a file from the marked set" do
      temp_dir = SpecHelper.create_temp_dir("fm_tm")
      begin
        %w[a.txt b.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        marks = fm.marked

        marks.size.should eq(0)
        fm.toggle_mark
        marks.size.should eq(1)
        fm.toggle_mark
        marks.size.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "can hold marks from multiple files" do
      temp_dir = SpecHelper.create_temp_dir("fm_tm_multi")
      begin
        %w[a.txt b.txt c.txt].each { |n| SpecHelper.create_temp_file(temp_dir, n, "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        marks = fm.marked

        [0, 1, 2].each do |idx|
          fm.scroll = idx
          fm.toggle_mark
        end
        marks.size.should eq(3)

        fm.scroll = 1
        fm.toggle_mark
        marks.size.should eq(2)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Yank / paste ───────────────────────────────────────────────────────────
  describe "yank_files" do
    it "copies the current file into the clipboard in :copy mode" do
      temp_dir = SpecHelper.create_temp_dir("fm_yank")
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

  # ── Search ─────────────────────────────────────────────────────────────────
  describe "start_search / live_search" do
    it "enters search input mode" do
      temp_dir = SpecHelper.create_temp_dir("fm_ss")
      begin
        %w[alpha.txt beta.txt gamma.txt].each { |n|
          SpecHelper.create_temp_file(temp_dir, n, "x")
        }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        input = fm.input_mode

        input.active.should be_false
        fm.start_search
        input.active.should be_true
        input.mode.should eq(:search)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "narrows the list as the user types (live_search)" do
      temp_dir = SpecHelper.create_temp_dir("fm_ls")
      begin
        %w[alpha.txt beta.txt gamma.txt].each { |n|
          SpecHelper.create_temp_file(temp_dir, n, "x")
        }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager
        input = fm.input_mode

        fm.start_search
        %w[a l p h a].each { |ch| input.handle_key(ch) }
        fm.live_search
        dm.list.size.should eq(1)
        File.basename(dm.list[0]).should eq("alpha.txt")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Delete files ──────────────────────────────────────────────────────────
  describe "delete_files" do
    it "sends marked files to trash" do
      temp_dir = SpecHelper.create_temp_dir("fm_df")
      begin
        path = SpecHelper.create_temp_file(temp_dir, "to_trash.txt", "bye")

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        trash_dir = File.join(ENV["HOME"], ".local", "share", "fff", "trash")

        fm.marked = Set{path}
        fm.scroll = 0
        term.queue_answers("y") # confirm_inline: approve delete
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
      temp_dir = SpecHelper.create_temp_dir("fm_df_nomark")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "x")

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        fm.delete_files.should be_nil
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Paste files ───────────────────────────────────────────────────────────
  describe "paste_files" do
    it "copies files from clipboard to current directory (copy mode)" do
      src_dir = SpecHelper.create_temp_dir("fm_pf_src")
      dst_dir = SpecHelper.create_temp_dir("fm_pf_dst")
      begin
        src_file = SpecHelper.create_temp_file(src_dir, "copy_me.txt", "content")

        fm, term = IntegrationHelper.create_test_file_manager(src_dir)
        fm.clipboard = [src_file]
        fm.clipboard_mode = :copy

        # Switch FM to destination directory
        fm.dir_manager = FFF::DirectoryManager.new(dst_dir)
        fm.dir_manager.read!

        term.queue_answers("y") # confirm_inline for copy mode if needed
        fm.paste_files

        dest_file = File.join(dst_dir, "copy_me.txt")
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
      temp_dir = SpecHelper.create_temp_dir("fm_sr")
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

  # ── New file / directory ───────────────────────────────────────────────────
  describe "new_directory / new_file" do
    it "creates a new subdirectory" do
      temp_dir = SpecHelper.create_temp_dir("fm_nd")
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
      temp_dir = SpecHelper.create_temp_dir("fm_nf")
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

  # ── Executable toggle ──────────────────────────────────────────────────────
  describe "toggle_executable" do
    it "adds execute permission to a regular file" do
      temp_dir = SpecHelper.create_temp_dir("fm_te_on")
      begin
        path = SpecHelper.create_temp_file(temp_dir, "script.sh", "#!/bin/bash\necho hi")
        File.chmod(path, File.info(path).permissions & ~File::Permissions::OwnerExecute)

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        term.queue_answers("y") # confirm_inline: approve toggle
        fm.scroll = 0
        fm.toggle_executable
        (File.info(path).permissions.includes?(::File::Permissions::OwnerExecute)).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "double-toggles back to original permissions" do
      temp_dir = SpecHelper.create_temp_dir("fm_te_off")
      begin
        path = SpecHelper.create_temp_file(temp_dir, "script.sh", "#!/bin/bash\necho hi")
        File.chmod(path, File.info(path).permissions | File::Permissions::OwnerExecute)

        fm, term = IntegrationHelper.create_test_file_manager(temp_dir)
        term.queue_answers("y", "y") # two confirm_inline approvals
        fm.scroll = 0
        fm.toggle_executable # off
        fm.toggle_executable # on again
        (File.info(path).permissions.includes?(::File::Permissions::OwnerExecute)).should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── Error display ──────────────────────────────────────────────────────────
  describe "show_error" do
    it "stores the message and a future expiry" do
      temp_dir = SpecHelper.create_temp_dir("fm_se")
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
      temp_dir = SpecHelper.create_temp_dir("fm_se_nil")
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
      temp_dir = SpecHelper.create_temp_dir("fm_csm")
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
      temp_dir = SpecHelper.create_temp_dir("fm_tsr")
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
      temp_dir = SpecHelper.create_temp_dir("fm_ps")
      begin
        10.times { |i| SpecHelper.create_temp_file(temp_dir, "f_#{i}.txt", "x") }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)

        fm.prev_scroll.should eq(-1)
        fm.prev_page_offset.should eq(-1)

        fm.redraw # no TTY side-effect because MockTerminal silences everything
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
      temp_dir = SpecHelper.create_temp_dir("fm_real")
      begin
        IntegrationHelper.create_realistic_test_structure(temp_dir)

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager

        dm.list.size.should be > 0
        dm.list.any? { |f| File.basename(f) == "document.txt" }.should be_true
        dm.list.any? { |f| File.basename(f) == "README.md" }.should be_true
        # subdirectory 'documents' is visible; internal_doc.txt is inside it
        dm.list.any? { |f| File.basename(f) == "documents" }.should be_true
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  # ── search+scroll interaction ─────────────────────────────────────────────
  describe "search list size change with scroll" do
    it "does not exceed filtered list size on cursor_down" do
      temp_dir = SpecHelper.create_temp_dir("fm_slsc")
      begin
        %w[alpha.txt beta.txt gamma.txt].each { |n|
          SpecHelper.create_temp_file(temp_dir, n, "x")
        }

        fm, _term = IntegrationHelper.create_test_file_manager(temp_dir)
        dm = fm.dir_manager

        fm.start_search
        %w[a l p h a].each { |ch|
          fm.input_mode.handle_key(ch)
        }
        fm.live_search
        dm.list.size.should eq(1) # only alpha.txt

        fm.scroll = 1
        fm.cursor_down
        fm.scroll.should eq(0) # clamped
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end
end
