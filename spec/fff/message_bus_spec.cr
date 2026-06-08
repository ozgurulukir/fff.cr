require "../../src/fff/message_bus.cr"
require "spec"

describe FFF::MessageBus do
  describe "#initialize" do
    it "starts with empty message list" do
      bus = FFF::MessageBus.new
      bus.messages.should be_empty
    end
  end

  describe "#push" do
    it "adds a message to the queue" do
      bus = FFF::MessageBus.new
      bus.push("test error", FFF::MessageType::Error)
      bus.messages.size.should eq(1)
    end

    it "ignores empty text messages" do
      bus = FFF::MessageBus.new
      bus.push("", FFF::MessageType::Error)
      bus.messages.should be_empty
    end

    it "stores message with correct type" do
      bus = FFF::MessageBus.new
      bus.push("ok", FFF::MessageType::Success)
      bus.messages[0].type.should eq(FFF::MessageType::Success)
    end

    it "stores message with custom duration" do
      bus = FFF::MessageBus.new
      bus.push("ok", FFF::MessageType::Info, 5.seconds)
      bus.messages[0].expires_at.should be > (Time.utc + 4.seconds)
    end
  end

  describe "convenience methods" do
    it "error method pushes error message" do
      bus = FFF::MessageBus.new
      bus.error("fail")
      bus.messages[0].type.should eq(FFF::MessageType::Error)
      bus.messages[0].text.should eq("fail")
    end

    it "success method pushes success message" do
      bus = FFF::MessageBus.new
      bus.success("done")
      bus.messages[0].type.should eq(FFF::MessageType::Success)
    end

    it "warning method pushes warning message" do
      bus = FFF::MessageBus.new
      bus.warning("careful")
      bus.messages[0].type.should eq(FFF::MessageType::Warning)
    end

    it "info method pushes info message" do
      bus = FFF::MessageBus.new
      bus.info("note")
      bus.messages[0].type.should eq(FFF::MessageType::Info)
    end
  end

  describe "#current" do
    it "returns nil for empty bus" do
      bus = FFF::MessageBus.new
      bus.current.should be_nil
    end

    it "returns the most recent non-expired message" do
      bus = FFF::MessageBus.new
      bus.push("old", FFF::MessageType::Info, 0.001.seconds)
      bus.push("new", FFF::MessageType::Success)
      bus.current.not_nil!.text.should eq("new")
    end

    it "removes expired messages on current call" do
      bus = FFF::MessageBus.new
      bus.push("expired", FFF::MessageType::Info, 0.001.seconds)
      sleep 10.milliseconds
      bus.push("fresh", FFF::MessageType::Success)
      bus.current
      bus.messages.any? { |m| m.text == "expired" }.should be_false
    end
  end

  describe "#tick!" do
    it "removes expired messages" do
      bus = FFF::MessageBus.new
      bus.push("msg", FFF::MessageType::Info, 0.001.seconds)
      sleep 10.milliseconds
      bus.tick!
      bus.messages.should be_empty
    end

    it "keeps non-expired messages" do
      bus = FFF::MessageBus.new
      bus.push("msg", FFF::MessageType::Info, 10.seconds)
      bus.tick!
      bus.messages.size.should eq(1)
    end
  end

  describe "#clear" do
    it "removes all messages" do
      bus = FFF::MessageBus.new
      bus.push("a", FFF::MessageType::Error)
      bus.push("b", FFF::MessageType::Success)
      bus.clear
      bus.messages.should be_empty
    end
  end

  describe FFF::Message do
    describe "#icon" do
      it "returns error icon for Error type" do
        msg = FFF::Message.new("err", FFF::MessageType::Error)
        msg.icon.should eq("❌ ")
      end

      it "returns success icon for Success type" do
        msg = FFF::Message.new("ok", FFF::MessageType::Success)
        msg.icon.should eq("✓ ")
      end

      it "returns warning icon for Warning type" do
        msg = FFF::Message.new("warn", FFF::MessageType::Warning)
        msg.icon.should eq("⚠ ")
      end

      it "returns info icon for Info type" do
        msg = FFF::Message.new("note", FFF::MessageType::Info)
        msg.icon.should eq("ℹ ")
      end
    end

    describe "#expired?" do
      it "returns false for fresh messages" do
        msg = FFF::Message.new("hi", FFF::MessageType::Info, 10.seconds)
        msg.expired?.should be_false
      end

      it "returns true after duration expires" do
        msg = FFF::Message.new("bye", FFF::MessageType::Info, 0.001.seconds)
        sleep 10.milliseconds
        msg.expired?.should be_true
      end
    end
  end
end
