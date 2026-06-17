require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/navigation_handlers.cr"
require "../../src/fff/directory_manager.cr"
require "../../src/fff/config.cr"
require "../../src/fff/terminal.cr"

class DummyNavigator
  include FFF::NavigationHandlers

  property scroll : Int32
  property page_offset : Int32
  getter marked : Set(String)
  property prev_scroll : Int32
  property prev_page_offset : Int32
  property prev_dir : String?
  property prev_child : String?
  property force_full_redraw : Bool
  property show_help : Bool
  property git_branch : String
  property git_status : String

  def initialize(@dir_manager : FFF::DirectoryManager, @config : FFF::Config, @term : FFF::Terminal)
    @scroll = 0
    @page_offset = 0
    @marked = Set(String).new
    @prev_scroll = -1
    @prev_page_offset = -1
    @prev_dir = nil
    @prev_child = nil
    @force_full_redraw = false
    @show_help = false
    @git_branch = ""
    @git_status = ""
  end

  def show_error(msg : String)
  end

  def show_info(msg : String)
  end
end

describe FFF::NavigationHandlers do
  describe "#cursor_up" do
    it "decrements scroll when list is non-empty" do
      temp_dir = SpecHelper.create_temp_dir("test_cursor_up")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "a")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = FFF::Terminal.new
        nav = DummyNavigator.new(dir_manager, config, term)
        nav.scroll = 5
        nav.cursor_up
        nav.scroll.should eq(4)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "clamps scroll at 0" do
      dir_manager = FFF::DirectoryManager.new(Dir.tempdir)
      config = FFF::Config.new
      term = FFF::Terminal.new
      nav = DummyNavigator.new(dir_manager, config, term)
      nav.scroll = 0
      nav.cursor_up
      nav.scroll.should eq(0)
    end

    it "does nothing when list is empty" do
      dir_manager = FFF::DirectoryManager.new(Dir.tempdir)
      config = FFF::Config.new
      term = FFF::Terminal.new
      nav = DummyNavigator.new(dir_manager, config, term)
      nav.scroll = 0
      nav.cursor_up
      nav.scroll.should eq(0)
    end
  end

  describe "#cursor_down" do
    it "increments scroll when list is non-empty" do
      temp_dir = SpecHelper.create_temp_dir("test_cursor_down")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "a")
        SpecHelper.create_temp_file(temp_dir, "b.txt", "b")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = FFF::Terminal.new
        nav = DummyNavigator.new(dir_manager, config, term)
        nav.scroll = 0
        nav.cursor_down
        nav.scroll.should eq(1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "clamps scroll at list size - 1" do
      temp_dir = SpecHelper.create_temp_dir("test_cursor_down")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "a")
        SpecHelper.create_temp_file(temp_dir, "b.txt", "b")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = FFF::Terminal.new
        nav = DummyNavigator.new(dir_manager, config, term)
        nav.scroll = dir_manager.list.size
        nav.cursor_down
        nav.scroll.should eq(dir_manager.list.size - 1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#page_up" do
    it "scrolls up by max_items" do
      temp_dir = SpecHelper.create_temp_dir("test_page_up")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "a")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = FFF::Terminal.new
        nav = DummyNavigator.new(dir_manager, config, term)
        nav.scroll = 5
        nav.page_up
        expected = {5 - term.max_items, 0}.max
        nav.scroll.should eq(expected)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#page_down" do
    it "scrolls down by max_items" do
      temp_dir = SpecHelper.create_temp_dir("test_page_down")
      begin
        30.times { |i| SpecHelper.create_temp_file(temp_dir, "f#{i}.txt", "x") }

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = FFF::Terminal.new
        nav = DummyNavigator.new(dir_manager, config, term)
        nav.scroll = 0
        nav.page_down
        expected = {0 + term.max_items, dir_manager.list.size - 1}.min
        nav.scroll.should eq(expected)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#go_top" do
    it "sets scroll and page_offset to 0" do
      temp_dir = SpecHelper.create_temp_dir("test_go_top")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "a")
        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = FFF::Terminal.new
        nav = DummyNavigator.new(dir_manager, config, term)
        nav.scroll = 10
        nav.page_offset = 5
        nav.go_top
        nav.scroll.should eq(0)
        nav.page_offset.should eq(0)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#go_bottom" do
    it "sets scroll to last item" do
      temp_dir = SpecHelper.create_temp_dir("test_go_bottom")
      begin
        SpecHelper.create_temp_file(temp_dir, "a.txt", "a")
        SpecHelper.create_temp_file(temp_dir, "b.txt", "b")

        dir_manager = FFF::DirectoryManager.new(temp_dir)
        dir_manager.read!
        config = FFF::Config.new
        term = FFF::Terminal.new
        nav = DummyNavigator.new(dir_manager, config, term)
        nav.go_bottom
        nav.scroll.should eq(dir_manager.list.size - 1)
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#adjust_page_offset" do
    it "moves page_offset up when scroll drops below it" do
      dir_manager = FFF::DirectoryManager.new(Dir.tempdir)
      config = FFF::Config.new
      term = FFF::Terminal.new
      nav = DummyNavigator.new(dir_manager, config, term)
      nav.scroll = 5
      nav.page_offset = 10
      nav.adjust_page_offset
      nav.page_offset.should eq(5)
    end

    it "moves page_offset down when scroll exceeds viewport" do
      dir_manager = FFF::DirectoryManager.new(Dir.tempdir)
      config = FFF::Config.new
      term = FFF::Terminal.new
      nav = DummyNavigator.new(dir_manager, config, term)
      nav.scroll = 30
      nav.page_offset = 0
      nav.adjust_page_offset
      expected = 30 - term.max_items + 1
      nav.page_offset.should eq(expected)
    end
  end
end
