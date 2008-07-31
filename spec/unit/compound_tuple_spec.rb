require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module Unison
  module CompoundTuple
    describe Base do
      attr_reader :tuple_class, :tuple

      describe ".basename" do
        it "returns the last segment of name" do
          tuple_class = Class.new(CompoundTuple::Base)
          stub(tuple_class).name {"Foo::Bar::Baz"}
          tuple_class.basename.should == "Baz"
        end
      end

      context "a compound tuple" do
        attr_reader :nested_tuple_1, :nested_tuple_2
        before do
          @nested_tuple_1 = User.new(:id => 1, :name => "Damon")
          @nested_tuple_2 = Photo.new(:id => 1, :name => "Silly Photo", :user_id => 1)
          @tuple = CompoundTuple::Base.new(nested_tuple_1, nested_tuple_2)
        end

        describe "#initialize" do
          it "sets #tuples to an array of the given operands" do
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
          context "when passed an Attribute" do
            it "retrieves the value of an Attribute from the appropriate nested Tuple" do
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

        describe "#==" do
          attr_reader :other_tuple
          context "when other Tuple#nested_tuples == #nested_tuples" do
            before do
              @other_tuple = CompoundTuple::Base.new(nested_tuple_1, nested_tuple_2)
              other_tuple.nested_tuples.should == tuple.nested_tuples
            end

            it "returns true" do
              tuple.should == other_tuple
            end
          end

          context "when other Tuple#attributes != #attributes" do
            before do
              @other_tuple = CompoundTuple::Base.new(User.new(:id => 100, :name => "Ross"), Photo.new(:id => 100, :name => "Super Photo", :user_id => 100))
              other_tuple.nested_tuples.should_not == tuple.nested_tuples
            end

            it "returns false" do
              tuple.should_not == other_tuple
            end
          end
        end
      end
    end
  end
end