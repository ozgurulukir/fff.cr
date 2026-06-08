require "../../src/fff/format_utils.cr"
require "../../src/fff/theme.cr"
require "../../src/fff/progress_bar.cr"
require "spec"

describe FFF::ProgressBar do
  describe "#initialize" do
    it "creates with default operation and zero total" do
      bar = FFF::ProgressBar.new
      bar.operation.should eq("Processing")
      bar.total.should eq(0)
      bar.current.should eq(0)
      bar.current_name.should eq("")
    end

    it "creates with custom operation and total" do
      bar = FFF::ProgressBar.new("Copying", 10)
      bar.operation.should eq("Copying")
      bar.total.should eq(10)
    end
  end

  describe "#update" do
    it "sets current progress and filename" do
      bar = FFF::ProgressBar.new("Test", 5)
      bar.update(3, "file.txt")
      bar.current.should eq(3)
      bar.current_name.should eq("file.txt")
    end
  end

  describe "#percentage" do
    it "returns 0 when total is 0" do
      bar = FFF::ProgressBar.new("Test", 0)
      bar.percentage.should eq(0)
    end

    it "returns 0 when total is negative" do
      bar = FFF::ProgressBar.new("Test", -5)
      bar.percentage.should eq(0)
    end

    it "calculates percentage correctly" do
      bar = FFF::ProgressBar.new("Test", 4)
      bar.update(2, "file.txt")
      bar.percentage.should eq(50)
    end

    it "clamps percentage at 100" do
      bar = FFF::ProgressBar.new("Test", 4)
      bar.update(10, "file.txt")
      bar.percentage.should eq(100)
    end

    it "returns 100 for complete progress" do
      bar = FFF::ProgressBar.new("Test", 10)
      bar.update(10, "file.txt")
      bar.percentage.should eq(100)
    end

    it "returns 0 at start" do
      bar = FFF::ProgressBar.new("Test", 10)
      bar.percentage.should eq(0)
    end
  end
end
