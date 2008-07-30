require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

module Unison
  module Relations
    describe InnerJoin do
      attr_reader :join, :predicate
      before do
        @predicate = photos_set[:user_id].eq(users_set[:id])
        @join = InnerJoin.new(users_set, photos_set, predicate)
      end

      describe "#initialize" do
        it "sets #operand_1, #operand_2, and #predicate" do
          join.operand_1.should == users_set
          join.operand_2.should == photos_set
          predicate.should == photos_set[:user_id].eq(users_set[:id])
        end

        context "when a Tuple inserted into #operand_1" do
          context "when the inserted Tuple creates a compound Tuple that matches the #predicate" do
            attr_reader :photo, :user, :tuple_class, :expected_tuple
            before do
              @tuple_class = join.tuple_class
              @photo = Photo.create(:id => 100, :user_id => 100, :name => "Photo 100")
              @user = User.new(:id => 100, :name => "Brian")
              @expected_tuple = tuple_class.new(user, photo)
              predicate.eval(expected_tuple).should be_true
            end

            it "adds the compound Tuple to the result of #read" do
              join.read.should_not include(expected_tuple)
              users_set.insert(user)
              join.read.should include(expected_tuple)
            end
          end

          context "when the inserted Tuple creates a compound Tuple that does not match the #predicate" do
            attr_reader :photo, :user, :tuple_class, :expected_tuple
            before do
              @tuple_class = join.tuple_class
              @photo = Photo.create(:id => 100, :user_id => 999, :name => "Photo 100")
              @user = User.new(:id => 100, :name => "Brian")
              @expected_tuple = tuple_class.new(user, photo)
              predicate.eval(expected_tuple).should be_false
            end

            it "does not add the compound Tuple to the result of #read" do
              join.read.should_not include(expected_tuple)
              users_set.insert(user)
              join.read.should_not include(expected_tuple)
            end
          end
        end

        context "when a Tuple inserted into #operand_2" do
          context "when the inserted Tuple creates a compound Tuple that matches the #predicate" do
            attr_reader :photo, :user, :tuple_class, :expected_tuple
            before do
              @tuple_class = join.tuple_class
              @photo = Photo.new(:id => 100, :user_id => 100, :name => "Photo 100")
              @user = User.create(:id => 100, :name => "Brian")
              @expected_tuple = tuple_class.new(user, photo)
              predicate.eval(expected_tuple).should be_true
            end

            it "adds the compound Tuple to the result of #read" do
              join.read.should_not include(expected_tuple)
              photos_set.insert(photo)
              join.read.should include(expected_tuple)
            end
          end

          context "when the inserted Tuple creates a compound Tuple that does not match the #predicate" do
            attr_reader :photo, :user, :tuple_class, :expected_tuple
            before do
              @tuple_class = join.tuple_class
              @photo = Photo.new(:id => 100, :user_id => 999, :name => "Photo 100")
              @user = User.create(:id => 100, :name => "Brian")
              @expected_tuple = tuple_class.new(user, photo)
              predicate.eval(expected_tuple).should be_false
            end

            it "does not add the compound Tuple to the result of #read" do
              join.read.should_not include(expected_tuple)
              photos_set.insert(photo)
              join.read.should_not include(expected_tuple)
            end
          end
        end

        context "when a Tuple deleted from #operand_1" do
          attr_reader :user, :tuple_class
          context "is a member of a compound Tuple that matches the #predicate" do
            attr_reader :photo, :compound_tuple
            before do
              @tuple_class = join.tuple_class
              @photo = Photo.create(:id => 100, :user_id => 100, :name => "Photo 100")
              @user = User.create(:id => 100, :name => "Brian")
              @compound_tuple = join.read.detect {|tuple| tuple[users_set] == user && tuple[photos_set] == photo}
              predicate.eval(compound_tuple).should be_true
              join.read.should include(compound_tuple)
            end

            it "deletes the compound Tuple from the result of #read" do
              users_set.delete(user)
              join.read.should_not include(compound_tuple)
            end
          end

          context "is not a member of a compound Tuple that matches the #predicate" do
            before do
              @tuple_class = join.tuple_class
              @user = User.create(:id => 100, :name => "Brian")
              join.read.any? do |compound_tuple|
                compound_tuple[users_set] == user
              end.should be_false
            end

            it "does not delete a compound Tuple from the result of #read" do
              lambda do
                users_set.delete(user)
              end.should_not change{join.read.length}
            end
          end
        end

        context "when a Tuple deleted from #operand_2" do
          attr_reader :photo, :tuple_class
          context "is a member of a compound Tuple that matches the #predicate" do
            attr_reader :user, :compound_tuple
            before do
              @tuple_class = join.tuple_class
              @photo = Photo.create(:id => 100, :user_id => 100, :name => "Photo 100")
              @user = User.create(:id => 100, :name => "Brian")
              @compound_tuple = join.read.detect {|tuple| tuple[users_set] == user && tuple[photos_set] == photo}
              predicate.eval(compound_tuple).should be_true
              join.read.should include(compound_tuple)
            end

            it "deletes the compound Tuple from the result of #read" do
              photos_set.delete(photo)
              join.read.should_not include(compound_tuple)
            end
          end

          context "is not a member of a compound Tuple that matches the #predicate" do
            before do
              @tuple_class = join.tuple_class
              @photo = Photo.create(:id => 100, :user_id => 100, :name => "Photo 100")
              join.read.any? do |compound_tuple|
                compound_tuple[photos_set] == photo
              end.should be_false
            end

            it "does not delete a compound Tuple from the result of #read" do
              lambda do
                photos_set.delete(photo)
              end.should_not change{join.read.length}
            end
          end          
        end

        context "when passed in #predicate is a constant value Predicate" do
          it "raises an ArgumentError"
        end
      end

      describe "#read" do
        it "returns all tuples in its operands for which its predicate returns true" do
          tuples = join.read
          tuples.size.should == 3

          tuples[0][users_set[:id]].should == 1
          tuples[0][users_set[:name]].should == "Nathan"
          tuples[0][photos_set[:id]].should == 1
          tuples[0][photos_set[:user_id]].should == 1
          tuples[0][photos_set[:name]].should == "Photo 1"

          tuples[1][users_set[:id]].should == 1
          tuples[1][users_set[:name]].should == "Nathan"
          tuples[1][photos_set[:id]].should == 2
          tuples[1][photos_set[:user_id]].should == 1
          tuples[1][photos_set[:name]].should == "Photo 2"

          tuples[2][users_set[:id]].should == 2
          tuples[2][users_set[:name]].should == "Corey"
          tuples[2][photos_set[:id]].should == 3
          tuples[2][photos_set[:user_id]].should == 2
          tuples[2][photos_set[:name]].should == "Photo 3"
        end
      end

      describe "#on_insert" do
        context "when a Tuple is inserted into #operand_1" do
          attr_reader :photo

          context "when the inserted Tuple creates a compound Tuple that matches the #predicate" do
            before do
              @photo = Photo.create(:id => 100, :user_id => 100, :name => "Photo 100")
            end

            it "invokes the block" do
              inserted = nil
              join.on_insert do |tuple|
                inserted = tuple
              end
              user = User.create(:id => 100, :name => "Brian")

              predicate.eval(inserted).should be_true
              inserted[photos_set].should == photo
              inserted[users_set].should == user
            end
          end

          context "when the inserted Tuple creates a compound Tuple that does not match the #predicate" do
            it "does not invoke the block" do
              join.on_insert do |tuple|
                raise "I should not be invoked"
              end
              User.create(:id => 100, :name => "Brian")
            end
          end
        end

        context "when a Tuple is inserted into #operand_2" do
          context "when the inserted Tuple creates a compound Tuple that matches the #predicate" do
            it "invokes the block" do
              inserted = nil
              join.on_insert do |tuple|
                inserted = tuple
              end
              photo = Photo.create(:id => 100, :user_id => 1, :name => "Photo 100")

              predicate.eval(inserted).should be_true
              inserted[photos_set].should == photo
              inserted[users_set].should == User.find(1)
            end
          end

          context "when the inserted Tuple creates a compound Tuple that does not match the #predicate" do
            it "does not invoke the block" do
              join.on_insert do |tuple|
                raise "I should not be invoked"
              end
              Photo.create(:id => 100, :user_id => 100, :name => "Photo 100")
            end
          end
        end
      end

      describe "#on_delete" do
        context "when a Tuple is deleted from #operand_1" do
          attr_reader :compound_tuple, :user
          context "when the deleted Tuple is a member of a compound Tuple that matches the #predicate" do
            before do
              @compound_tuple = join.read.first
              compound_tuple.should_not be_nil
              @user = compound_tuple[users_set]
            end

            it "invokes the block" do
              deleted = nil
              join.on_delete do |deleted_tuple|
                deleted = deleted_tuple
              end

              users_set.delete(user)
              deleted.should == compound_tuple
            end
          end

          context "when the deleted Tuple is not a member of a compound Tuple that matches the #predicate" do
            before do
              @user = User.create(:id => 100, :name => "Brian")
              join.read.all? do |compound_tuple|
                compound_tuple[users_set] != user
              end.should be_true
            end

            it "does not invoke the block" do
              join.on_delete do |deleted_tuple|
                raise "I should not be invoked"
              end
              users_set.delete(user)
            end
          end
        end

        context "when a Tuple is deleted from #operand_2" do
          attr_reader :compound_tuple, :photo
          context "when the deleted Tuple is a member of a compound Tuple that matches the #predicate" do
            before do
              @compound_tuple = join.read.first
              compound_tuple.should_not be_nil
              @photo = compound_tuple[photos_set]
            end

            it "invokes the block" do
              deleted = nil
              join.on_delete do |deleted_tuple|
                deleted = deleted_tuple
              end

              photos_set.delete(photo)
              deleted.should == compound_tuple
            end
          end

          context "when the deleted Tuple is not a member of a compound Tuple that matches the #predicate" do
            before do
              @photo = Photo.create(:id => 100, :user_id => 100, :name => "Photo 100")
              join.read.all? do |compound_tuple|
                compound_tuple[photos_set] != photo
              end.should be_true
            end

            it "does not invoke the block" do
              join.on_delete do |deleted_tuple|
                raise "I should not be invoked"
              end
              photos_set.delete(photo)
            end
          end
        end
      end
    end
  end
end
