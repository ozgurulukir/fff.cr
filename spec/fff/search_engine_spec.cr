require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/search_engine.cr"

describe FFF::SearchEngine do
  describe ".fuzzy_score" do
    it "gives 1000 for exact match" do
      FFF::SearchEngine.fuzzy_score("hello.txt", "hello.txt").should eq(1000)
    end

    it "gives 500 for prefix match" do
      score = FFF::SearchEngine.fuzzy_score("hello.txt", "hello")
      score.should eq(500)
    end

    it "gives a high score for substring match" do
      score = FFF::SearchEngine.fuzzy_score("hello.txt", "ello")
      score.should eq(219)
    end

    it "gives positive score for fuzzy match" do
      score = FFF::SearchEngine.fuzzy_score("hello_world.txt", "hlo")
      score.should be > 0
    end

    it "gives zero for no match" do
      score = FFF::SearchEngine.fuzzy_score("hello.txt", "xyz")
      score.should eq(0)
    end

    it "prioritizes prefix over substring" do
      prefix = FFF::SearchEngine.fuzzy_score("hello.txt", "hello")
      substring = FFF::SearchEngine.fuzzy_score("hello.txt", "ello")
      prefix.should be > substring
    end

    it "handles case insensitivity through fuzzy_match" do
      result = FFF::SearchEngine.fuzzy_match(["Hello.txt"], "hello")
      result.should contain("Hello.txt")
    end

    it "handles query longer than string" do
      FFF::SearchEngine.fuzzy_score("hi", "hello").should eq(0)
    end
  end

  describe ".fuzzy_match" do
    it "finds prefix matches" do
      list = ["hello.txt", "world.txt", "help.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "hel")
      result.should eq(["hello.txt", "help.txt"])
    end

    it "finds substring matches" do
      list = ["hello.txt", "world.txt", "yellow.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "ello")
      result.should eq(["hello.txt", "yellow.txt"])
    end

    it "finds fuzzy matches" do
      list = ["hello_world.txt", "hard_work.txt", "home.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "hwk")
      result.should contain("hard_work.txt")
    end

    it "handles empty query" do
      FFF::SearchEngine.fuzzy_score("hello.txt", "").should eq(100)
    end

    it "handles query longer than string" do
      FFF::SearchEngine.fuzzy_score("hi", "hello").should eq(0)
    end
  end

  describe ".fuzzy_match" do
    it "finds prefix matches" do
      list = ["hello.txt", "world.txt", "help.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "hel")
      result.should eq(["hello.txt", "help.txt"])
    end

    it "finds substring matches" do
      list = ["hello.txt", "world.txt", "yellow.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "ello")
      result.should eq(["hello.txt", "yellow.txt"])
    end

    it "finds fuzzy matches" do
      list = ["hello_world.txt", "hard_work.txt", "home.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "hwk")
      result.should contain("hard_work.txt")
    end

    it "returns empty for no match" do
      list = ["hello.txt", "world.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "xyz")
      result.should be_empty
    end

    it "handles empty query" do
      list = ["hello.txt", "world.txt"]
      FFF::SearchEngine.fuzzy_match(list, "").should eq(list)
    end

    it "handles empty list" do
      FFF::SearchEngine.fuzzy_match([] of String, "hello").should be_empty
    end

    it "sorts by relevance" do
      list = ["helloworld.txt", "hell.txt", "hello.txt"]
      result = FFF::SearchEngine.fuzzy_match(list, "hello")
      result[0].should eq("hello.txt")
    end
  end

  describe ".content_search" do
    it "searches file contents using ripgrep" do
      temp_dir = SpecHelper.create_temp_dir("test_content_search")
      begin
        SpecHelper.create_temp_file(temp_dir, "file1.txt", "hello world")
        SpecHelper.create_temp_file(temp_dir, "file2.txt", "goodbye world")

        # Check if rg is available
        rg_output = IO::Memory.new
        status = Process.run("rg", {"--version"}, output: rg_output, error: rg_output)
        if status.exit_code == 0
          results = FFF::SearchEngine.content_search("hello", temp_dir)
          results.should_not be_empty
        end
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "handles missing ripgrep gracefully" do
      FFF::SearchEngine.content_search("hello", "/tmp").should be_a(Array(String))
    end

    it "handles empty query" do
      temp_dir = SpecHelper.create_temp_dir("test_empty_query")
      begin
        results = FFF::SearchEngine.content_search("", temp_dir)
        results.should be_empty
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end
end
