require File.expand_path("#{File.dirname(__FILE__)}/../unison_spec_helper")

module Unison
  describe CompositeTuple do
    attr_reader :tuple_class, :tuple

    describe ".basename" do
      it "returns the last segment of name" do
        tuple_class = Class.new(CompositeTuple)
        stub(tuple_class).name {"Foo::Bar::Baz"}
        tuple_class.basename.should == "Baz"
      end
    end

    attr_reader :nested_tuple_1, :nested_tuple_2
    before do
      @nested_tuple_1 = User.new(:id => 1, :name => "Damon")
      @nested_tuple_2 = Photo.new(:id => 1, :name => "Silly Photo", :user_id => 1)
      @tuple = CompositeTuple.new(nested_tuple_1, nested_tuple_2)
    end

    describe "#initialize" do
      it "sets #nested_tuples to an array of the given operands" do
        tuple.nested_tuples.should == [nested_tuple_1, nested_tuple_2]
      end
    end

    describe "#compound?" do
      it "should be true" do
        tuple.should be_compound
      end
    end

    describe "#primitive?" do
      it "should be false" do
        tuple.should_not be_primitive
      end
    end

    describe "#[]" do
      context "when the #nested_tuples are PrimitiveTuples" do
        context "when passed an Attribute of a nested PrimitiveTuple" do
          it "retrieves the value from the PrimitiveTuple" do
            tuple[users_set[:id]].should == nested_tuple_1[users_set[:id]]
            tuple[photos_set[:id]].should == nested_tuple_2[photos_set[:id]]
          end
        end

        context "when passed a Relation" do
          it "retrieves the first nested Tuple belonging to that Relation" do
            tuple[users_set].should == nested_tuple_1
            tuple[photos_set].should == nested_tuple_2
          end
        end
      end

      context "when one of #nested_tuples is itself a CompositeTuple" do
        attr_reader :nested_tuple_3
        before do
          @nested_tuple_1 = User.new(:id => 1, :name => "Damon")
          @nested_tuple_2 = Photo.new(:id => 1, :name => "Silly Photo", :user_id => 1, :camera_id => 1)
          @nested_tuple_3 = Camera.new(:id => 1, :name => "Lomo")
          @tuple = CompositeTuple.new(CompositeTuple.new(nested_tuple_1, nested_tuple_2), nested_tuple_3)
        end

        context "when passed an Attribute of a doubly-nested PrimitiveTuple" do
          it "retrieves the value from the PrimitiveTuple" do
            tuple[users_set[:id]].should == nested_tuple_1[users_set[:id]]
            tuple[photos_set[:id]].should == nested_tuple_2[photos_set[:id]]
            tuple[cameras_set[:id]].should == nested_tuple_3[cameras_set[:id]]
          end
        end

        context "when passed a Relation" do
          it "retrieves the first nested PrimitiveTuple belonging to that relation" do
            tuple[users_set].should == nested_tuple_1
            tuple[photos_set].should == nested_tuple_2
            tuple[cameras_set].should == nested_tuple_3
          end
        end
      end
    end

    describe "#has_attribute?" do
      context "when passed a Relation" do
        it "returns true if #has_attribute? on any nested Tuple returns true" do
          tuple.should have_attribute(users_set)
          tuple.should have_attribute(photos_set)
          tuple.should_not have_attribute(cameras_set)
        end
      end

      context "when passed an Attribute" do
        it "returns true if #has_attribute? on any nested Tuple returns true" do
          tuple.should have_attribute(users_set[:id])
          tuple.should have_attribute(photos_set[:id])
          nested_tuple_1.should_not have_attribute(cameras_set[:id])
          tuple.should_not have_attribute(cameras_set[:id])
        end
      end

      context "when passed a Symbol" do
        it "returns true if #has_attribute? on any nested Tuple returns true" do
          tuple.should have_attribute(:id)
          tuple.should have_attribute(:user_id)
          tuple.should_not have_attribute(:bullcrap)
        end
      end
    end

    describe "#after_first_retain" do
      it "retains the #nested_tuples" do
        nested_tuple_1.should_not be_retained_by(tuple)
        nested_tuple_2.should_not be_retained_by(tuple)

        mock.proxy(tuple).after_first_retain
        tuple.retain_with(Object.new)

        nested_tuple_1.should be_retained_by(tuple)
        nested_tuple_2.should be_retained_by(tuple)
      end
    end

    describe "#after_last_release" do
      it "#releases the #nested_tuples" do
        retainer = Object.new
        tuple.retain_with(retainer)
        nested_tuple_1.should be_retained_by(tuple)
        nested_tuple_2.should be_retained_by(tuple)

        mock.proxy(tuple).after_last_release
        tuple.release_from(retainer)
        nested_tuple_1.should_not be_retained_by(tuple)
        nested_tuple_2.should_not be_retained_by(tuple)
      end
    end

    describe "#==" do
      attr_reader :other_tuple
      context "when other Tuple#nested_tuples == #nested_tuples" do
        before do
          @other_tuple = CompositeTuple.new(nested_tuple_1, nested_tuple_2)
          other_tuple.nested_tuples.should == tuple.nested_tuples
        end

        it "returns true" do
          tuple.should == other_tuple
        end
      end

      context "when other Tuple#attributes != #attributes" do
        before do
          @other_tuple = CompositeTuple.new(User.new(:id => 100, :name => "Ross"), Photo.new(:id => 100, :name => "Super Photo", :user_id => 100))
          other_tuple.nested_tuples.should_not == tuple.nested_tuples
        end

        it "returns false" do
          tuple.should_not == other_tuple
        end
      end
    end
  end
end