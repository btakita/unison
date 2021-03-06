require File.expand_path("#{File.dirname(__FILE__)}/../../unison_spec_helper")

module Unison
  module Tuples
    describe Topic do
      attr_reader :topic_class, :topic, :subject
      before do
        @subject = User.find("corey")
        @topic_class = Class.new(Topic) do
          def self.name; "UserTopic"; end
          attribute_reader :id, :string
          attribute_reader :user_id, :string

          belongs_to :user
          subject :user

          expose :accounts, :team, :example_signal

          relates_to_many :accounts do
            subject.accounts.project(:id, :user_id, :name)
          end

          def example_signal
            @example_signal ||= subject.signal(:show_fans) do |show_fans|
              if show_fans
                subject.fans
              else
                subject.heroes
              end
            end
          end
        end
        @topic = topic_class.new(:user_id => subject.id)
      end

      describe ".expose" do
        it "adds the passed-in names to .exposed_method_names" do
          publicize topic_class, :exposed_method_names

          topic_class.exposed_method_names.should include(:accounts)
          topic_class.exposed_method_names.should include(:team)
        end

        it "causes #exposed_objects to contain the return value of each exposed method name" do
          topic.exposed_objects.should include(topic.accounts)
          topic.exposed_objects.should include(topic.team)
          topic.exposed_objects.should include(topic.example_signal)
        end
      end

      describe ".subject" do
        it "causes #subject to delegate to the passed-in method name" do
          topic.subject.should == topic.user
        end
      end

      describe "#subject" do
        context "when .subject was called" do
          it "delegates to the method name passed to .subject" do
            topic.subject.should == topic.user
          end
        end

        context "when .subject was not called" do
          it "raises a NoSubjectError" do
            invalid_topic_class = Class.new(Topic) do
              member_of Relations::Set.new(:topics)
              attribute_reader :id, :string
            end
            lambda do
              invalid_topic_class.new.subject
            end.should raise_error(Topic::NoSubjectError)
          end
        end
      end

      describe "#method_missing" do
        it "delegates to #subject" do
          team = subject.team
          mock.proxy(subject).team
          topic.team.should == team
        end
      end

      describe "#exposed_method_names" do
        it "delegates to .exposed_method_names on the class" do
          publicize topic_class, :exposed_method_names
          topic.exposed_method_names.should == topic_class.exposed_method_names
        end
      end

      describe "#exposed_objects" do
        it "returns the results of sending all #exposed_method_names" do
          topic.exposed_objects.should == topic.exposed_method_names.map do |method_name|
            topic.send(method_name)
          end
        end
      end

      describe "#exposed_relations" do
        it "returns only those #exposed_objects that are subclasses of Relations::Relation" do
          topic.exposed_objects.any? {|object| object.is_a?(Signals::Signal)}
          exposed_relations = topic.exposed_relations
          exposed_relations.should_not be_empty
          exposed_relations.each do |object|
            object.class.ancestors.should include(Relations::Relation)
          end
        end
      end

      describe "#exposed_signals" do
        it "returns only those #exposed_objects that are subclasses of Signals::Signal" do
          topic.exposed_objects.any? {|object| object.is_a?(Relations::Relation)}
          exposed_signals = topic.exposed_signals
          exposed_signals.should_not be_empty
          exposed_signals.each do |object|
            object.class.ancestors.should include(Signals::Signal)
          end
        end
      end

      context "when #retained?" do
        attr_reader :retainer
        before do
          @retainer = Object.new
          topic.retain_with(retainer)
        end

        after do
          topic.release_from(retainer)
        end

        it "retains all exposed Objects" do
          topic.exposed_objects.each do |exposed_object|
            exposed_object.should be_retained_by(topic)
          end
        end

        it "retains the initial #value of all #exposed_signals" do
          topic.exposed_signals.each do |signal|
            signal.value.should be_retained_by(topic)
          end
        end

        it "subscribes to the initial #value of all #exposed_signals" do
          topic.exposed_signals.each do |signal|
            relation = signal.value
            publicize relation, :insert_subscription_node, :delete_subscription_node, :tuple_update_subscription_node

            relation.insert_subscription_node.should_not be_empty
            relation.delete_subscription_node.should_not be_empty
            relation.tuple_update_subscription_node.should_not be_empty
          end
        end

        it "sets the :hash_representation Attribute value to a Hash (type => id => attributes) of the exposed objects" do
          subject.team_id.should == "mangos"

          topic[:hash_representation].should == {
            "Account" => {
              "corey_account" => topic.accounts.find("corey_account").hash_representation.stringify_keys,
            },
            "Team" => {
              "mangos" => Team.find("mangos").hash_representation.stringify_keys,
            },
            "User" => {
              "nathan" => subject.fans.find("nathan").hash_representation.stringify_keys,
              "jan" => subject.fans.find("jan").hash_representation.stringify_keys
            }
          }
        end

        describe "#json_representation" do
          it "returns #hash_representation.to_json" do
            JSON.parse(topic.json_representation).should == JSON.parse(topic.hash_representation.to_json)
          end
        end

        context "when an event is triggered on a directly exposed Relation" do
          context "when an insert event is triggered on a directly exposed Relation" do
            it "inserts the Tuple's #attributes into the memoized #hash_representation" do
              representation = topic.hash_representation
              representation["Account"]["corey_inserted_account"].should be_nil
              inserted_account = Account.create(:id => "corey_inserted_account", :user_id => "corey", :name => "inserted account")
              representation["Account"]["corey_inserted_account"].should == topic.accounts.find("corey_inserted_account").hash_representation.stringify_keys
            end

            it "triggers the on_update event for the :hash_representation PrimitiveAttribute" do
              update_args = []
              topic.on_update(retainer) do |attribute, old_value, new_value|
                update_args.push [attribute, old_value, new_value]
              end

              inserted_account = Account.create(:id => "corey_inserted_account", :user_id => "corey", :name => "inserted account")
              update_args.should == [[topic.set[:hash_representation], topic.hash_representation, topic.hash_representation]]
            end
          end

          context "when a delete event is triggered on a directly exposed Relation" do
            it "removes the Tuple's #attributes from the memoized #hash_representation" do
              representation = topic.hash_representation
              representation["Account"]["corey_account"].should_not be_nil

              Account.find("corey_account").delete
              representation["Account"].should_not have_key("corey_account")
            end

            it "triggers the on_update event for the :hash_representation PrimitiveAttribute" do
              update_args = []
              topic.on_update(retainer) do |attribute, old_value, new_value|
                update_args.push [attribute, old_value, new_value]
              end

              Account.find("corey_account").delete
              update_args.should == [ [topic.set[:hash_representation], topic.hash_representation, topic.hash_representation] ]
            end
          end

          context "when a tuple_update event is triggered on a directly exposed Relation" do
            it "updates the changed Tuple's #attributes in the memoized #hash_representation" do
              representation = topic.hash_representation
              account = Account.find("corey_account")
              new_value = "#{account.name} with more baggage"

              representation["Account"]["corey_account"]["name"].should_not == new_value
              account.name = new_value
              representation["Account"]["corey_account"]["name"].should == new_value
            end

            it "triggers the on_update event for the :hash_representation PrimitiveAttribute" do
              representation = topic.hash_representation
              account = Account.find("corey_account")
              new_value = "#{account.name} with more baggage"

              update_args = []
              topic.on_update(retainer) do |attribute, old_value, new_value|
                update_args.push [attribute, old_value, new_value]
              end

              account.name = new_value

              update_args.should == [[topic.set[:hash_representation], topic.hash_representation, topic.hash_representation]]
            end
          end
        end

        context "when an event is triggered on a Relation that is the initial #value of an exposed Signal" do
          before do
            subject.team_id.should == "mangos"
            topic.example_signal.value.should == subject.fans
          end

          context "when an insert event is triggered on a Relation that is the initial #value of an exposed Signal" do
            it "inserts the Tuple's #attributes into the memoized #hash_representation" do
              representation = topic.hash_representation
              representation["User"]["ross"].should be_nil
              Friendship.create(:id => "ross_to_corey", :from_id => "ross", :to_id => "corey")
              representation["User"]["ross"].should == subject.fans.find("ross").hash_representation.stringify_keys
            end

            it "triggers the on_update event for the :hash_representation PrimitiveAttribute" do
              update_args = []
              topic.on_update(retainer) do |attribute, old_value, new_value|
                update_args.push [attribute, old_value, new_value]
              end

              Friendship.create(:id => "ross_to_corey", :from_id => "ross", :to_id => "corey")
              update_args.should == [[topic.set[:hash_representation], topic.hash_representation, topic.hash_representation]]
            end
          end

          context "when a delete event is triggered on a Relation that is the initial #value of an exposed Signal" do
            it "removes the Tuple's #attributes from the memoized #hash_representation" do
              representation = topic.hash_representation
              representation["User"]["nathan"].should_not be_nil

              User.find("nathan").delete
              representation["User"].should_not have_key("nathan")
            end

            it "triggers the on_update event for the :hash_representation PrimitiveAttribute" do
              update_args = []
              topic.on_update(retainer) do |attribute, old_value, new_value|
                update_args.push [attribute, old_value, new_value]
              end

              User.find("nathan").delete
              update_args.should == [ [topic.set[:hash_representation], topic.hash_representation, topic.hash_representation] ]
            end
          end

          context "when a tuple_update event is triggered on a Relation that is the initial #value of an exposed Signal" do
            it "updates the changed Tuple's #attributes in the memoized #hash_representation" do
              representation = topic.hash_representation
              user = User.find("nathan")
              new_value = "#{user.name} with more baggage"

              representation["User"]["nathan"]["name"].should_not == new_value
              user.name = new_value
              representation["User"]["nathan"]["name"].should == new_value
            end

            it "triggers the on_update event for the :hash_representation PrimitiveAttribute" do
              representation = topic.hash_representation
              user = User.find("nathan")
              new_value = "#{user.name} with more baggage"

              update_args = []
              topic.on_update(retainer) do |attribute, old_value, new_value|
                update_args.push [attribute, old_value, new_value]
              end

              user.name = new_value

              update_args.should == [[topic.set[:hash_representation], topic.hash_representation, topic.hash_representation]]
            end
          end
        end

        context "when the #value of an exposed Signal changes" do
          attr_reader :old_value, :new_value
          def change_signal_value
            subject.show_fans = !subject.show_fans
            @new_value = topic.example_signal.value
            old_value.should_not == new_value
          end

          context "for the first time" do
            before do
              @old_value = topic.example_signal.value
            end

            it "releases the old #value of the exposed Signal" do
              old_value.should be_retained_by(topic)
              change_signal_value
              old_value.should_not be_retained_by(topic)
            end

            it "retains the new #value of the exposed Signal" do
              expected_new_value = subject.heroes
              expected_new_value.should_not be_retained_by(topic)

              change_signal_value
              new_value.should == expected_new_value

              new_value.should be_retained_by(topic)
            end

            it "unsubscribes from the old #value of the exposed Signal" do
              publicize old_value, :insert_subscription_node, :delete_subscription_node, :tuple_update_subscription_node
              old_value.insert_subscription_node.should_not be_empty
              old_value.delete_subscription_node.should_not be_empty
              old_value.tuple_update_subscription_node.should_not be_empty

              change_signal_value

              old_value.insert_subscription_node.should be_empty
              old_value.delete_subscription_node.should be_empty
              old_value.tuple_update_subscription_node.should be_empty
            end

            it "subscribes to the new #value of the exposed Signal" do
              expected_new_value = subject.heroes

              publicize expected_new_value, :insert_subscription_node, :delete_subscription_node, :tuple_update_subscription_node

              expected_new_value.insert_subscription_node.should be_empty
              expected_new_value.delete_subscription_node.should be_empty
              expected_new_value.tuple_update_subscription_node.should be_empty

              change_signal_value
              new_value.should == expected_new_value

              expected_new_value.insert_subscription_node.should_not be_empty
              expected_new_value.delete_subscription_node.should_not be_empty
              expected_new_value.tuple_update_subscription_node.should_not be_empty
            end

            context "when #tuples of the old #value is different than #tuples of the new value" do
              attr_reader :expected_new_value
              before do
                @expected_new_value = subject.heroes
                expected_new_value.tuples.should_not have_same_elements_as(old_value.tuples)
              end

              after do
                expected_new_value.should == new_value
              end

              it "removes the difference between the old #value's #tuples and new #value's #tuples to the #hash_representation" do
                old_value.tuples.each do |tuple|
                  topic[:hash_representation][tuple.set.tuple_class.basename][tuple[:id]].should == tuple.hash_representation.stringify_keys
                end

                change_signal_value

                tuples_to_delete = old_value.tuples - new_value.tuples
                tuples_to_delete.should_not be_empty
                tuples_to_delete.each do |tuple|
                  topic[:hash_representation][tuple.set.tuple_class.basename].should_not have_key(tuple[:id])
                end
              end

              it "adds the difference between the new #value's #tuples and old #value's #tuples to the #hash_representation" do
                tuples_to_add = expected_new_value.tuples - old_value.tuples

                tuples_to_add.each do |tuple|
                  type = tuple.set.tuple_class.basename
                  if topic[:hash_representation].has_key?(type)
                    topic[:hash_representation][type].should_not have_key(tuple[:id])
                  end
                end

                change_signal_value

                tuples_to_add.each do |tuple|
                  topic[:hash_representation][tuple.set.tuple_class.basename][tuple[:id]].should == tuple.hash_representation.stringify_keys
                end
              end

              it "triggers an on_change event for the 'hash_representation' Attribute" do
                update_args = []
                topic.on_update(retainer) do |attribute, old, new|
                  update_args.push([attribute, old, new])
                end
                
                change_signal_value
                
                update_args.should == [[topic_class[:hash_representation], topic[:hash_representation], topic[:hash_representation]]]
              end
            end

            context "when #tuples of the old #value is identical to #tuples of the new value" do
              attr_reader :expected_new_value
              before do
                Friendship.create(:id => "corey_to_jan", :from_id => "corey", :to_id => "jan")
                Friendship.create(:id => "ross_to_corey", :from_id => "ross", :to_id => "corey")

                @expected_new_value = subject.heroes
                expected_new_value.tuples.should have_same_elements_as(old_value.tuples)
              end

              after do
                expected_new_value.should == new_value
              end

              it "does not change 'hash_representation' Attribute" do
                lambda do
                  change_signal_value
                end.should_not change { topic[:hash_representation] }
              end

              it "does not trigger an on_change event for the 'hash_representation' Attribute" do
                on_update_called = false
                topic.on_update(retainer) do |attribute, old_value, new_value|
                  on_update_called = true
                end

                change_signal_value
                on_update_called.should be_false
              end
            end
          end

          context "for the second time" do
            before do
              change_signal_value
              @old_value = topic.example_signal.value
            end

            it "releases the old #value of the exposed Signal" do
              old_value.should be_retained_by(topic)
              change_signal_value
              old_value.should_not be_retained_by(topic)
            end

            it "retains the new #value of the exposed Signal" do
              expected_new_value = subject.fans
              expected_new_value.should_not be_retained_by(topic)

              change_signal_value
              new_value.should == expected_new_value

              new_value.should be_retained_by(topic)
            end

            it "unsubscribes from the old #value of the exposed Signal" do
              publicize old_value, :insert_subscription_node, :delete_subscription_node, :tuple_update_subscription_node
              old_value.insert_subscription_node.should_not be_empty
              old_value.delete_subscription_node.should_not be_empty
              old_value.tuple_update_subscription_node.should_not be_empty

              change_signal_value

              old_value.insert_subscription_node.should be_empty
              old_value.delete_subscription_node.should be_empty
              old_value.tuple_update_subscription_node.should be_empty
            end

            it "subscribes to the new #value of the exposed Signal" do
              expected_new_value = subject.fans

              publicize expected_new_value, :insert_subscription_node, :delete_subscription_node, :tuple_update_subscription_node

              expected_new_value.insert_subscription_node.should be_empty
              expected_new_value.delete_subscription_node.should be_empty
              expected_new_value.tuple_update_subscription_node.should be_empty

              change_signal_value
              new_value.should == expected_new_value

              expected_new_value.insert_subscription_node.should_not be_empty
              expected_new_value.delete_subscription_node.should_not be_empty
              expected_new_value.tuple_update_subscription_node.should_not be_empty
            end
          end
        end

        context "when a Relation that is the #value of an exposed Signal is modified" do
          context "when the Relation is the initial #value of an exposed Signal" do
            context "when a Tuple is inserted into the Relation" do
              it "is inserted into the #hash_representation" do
                topic[:hash_representation]["User"].should_not have_key("ross")
                Friendship.create(:id => "ross_to_corey", :from_id => "ross", :to_id => "corey")
                topic[:hash_representation]["User"]["ross"].should == User.find("ross").hash_representation.stringify_keys
              end

              it "triggers an on_change event for the 'hash_representation' Attribute" do
                update_args = []
                topic.on_update(retainer) do |attribute, old, new|
                  update_args.push([attribute, old, new])
                end

                Friendship.create(:id => "ross_to_corey", :from_id => "ross", :to_id => "corey")

                update_args.should == [[topic_class[:hash_representation], topic[:hash_representation], topic[:hash_representation]]]
              end
            end

            context "when a Tuple is deleted from the Relation" do
              it "is deleted from the #hash_representation" do
                topic[:hash_representation]["User"]["jan"].should == User.find("jan").hash_representation.stringify_keys
                Friendship.find("jan_to_corey").delete
                topic[:hash_representation]["User"].should_not have_key("jan")
              end

              it "triggers an on_change event for the 'hash_representation' Attribute" do
                update_args = []
                topic.on_update(retainer) do |attribute, old, new|
                  update_args.push([attribute, old, new])
                end

                Friendship.find("jan_to_corey").delete

                update_args.should == [[topic_class[:hash_representation], topic[:hash_representation], topic[:hash_representation]]]
              end
            end

            context "when a Tuple is updated in the Relation" do
              it "is updated in the #hash_representation" do
                User.find("jan").name = "Jan-Christian"
                topic[:hash_representation]["User"]["jan"]["name"].should == "Jan-Christian"
              end

              it "triggers an on_change event for the 'hash_representation' Attribute" do
                update_args = []
                topic.on_update(retainer) do |attribute, old, new|
                  update_args.push([attribute, old, new])
                end

                User.find("jan").name = "Jan-Christian"

                update_args.should == [[topic_class[:hash_representation], topic[:hash_representation], topic[:hash_representation]]]
              end
            end
          end

          context "when the #value of the exposed Signal has changed at least once" do
            before do
              topic.example_signal.value.should == subject.fans
              subject.show_fans = false
              topic.example_signal.value.should == subject.heroes
            end

            context "when a Tuple is inserted into the Relation" do
              it "is inserted into the #hash_representation" do
                topic[:hash_representation]["User"].should_not have_key("jan")
                Friendship.create(:id => "corey_to_jan", :from_id => "corey", :to_id => "jan")
                topic[:hash_representation]["User"]["jan"].should == User.find("jan").hash_representation.stringify_keys
              end

              it "triggers an on_change event for the 'hash_representation' Attribute" do
                update_args = []
                topic.on_update(retainer) do |attribute, old, new|
                  update_args.push([attribute, old, new])
                end

                Friendship.create(:id => "corey_to_jan", :from_id => "corey", :to_id => "jan")

                update_args.should == [[topic_class[:hash_representation], topic[:hash_representation], topic[:hash_representation]]]
              end
            end

            context "when a Tuple is deleted from the Relation" do
              it "is deleted from the #hash_representation" do
                topic[:hash_representation]["User"]["ross"].should == User.find("ross").hash_representation.stringify_keys
                Friendship.find("corey_to_ross").delete
                topic[:hash_representation]["User"].should_not have_key("ross")
              end

              it "triggers an on_change event for the 'hash_representation' Attribute" do
                update_args = []
                topic.on_update(retainer) do |attribute, old, new|
                  update_args.push([attribute, old, new])
                end

                Friendship.find("corey_to_ross").delete

                update_args.should == [[topic_class[:hash_representation], topic[:hash_representation], topic[:hash_representation]]]
              end
            end

            context "when a Tuple is updated in the Relation" do
              it "is updated in the #hash_representation" do
                User.find("ross").name = "Jan-Christian"
                topic[:hash_representation]["User"]["ross"]["name"].should == "Jan-Christian"
              end

              it "triggers an on_change event for the 'hash_representation' Attribute" do
                update_args = []
                topic.on_update(retainer) do |attribute, old, new|
                  update_args.push([attribute, old, new])
                end

                User.find("ross").name = "Jan-Christian"

                update_args.should == [[topic_class[:hash_representation], topic[:hash_representation], topic[:hash_representation]]]
              end
            end

          end
        end

        context "after last release" do
          it "no longer memoizes the :hash_representation PrimitiveAttribute" do
            dont_allow(topic).create_hash_representation
            memoized_hash_representation = topic[:hash_representation]
            topic[:hash_representation].should equal(memoized_hash_representation)

            topic.release_from(retainer)
            topic.should_not be_retained

            mock.proxy(topic).create_hash_representation.twice
            topic[:hash_representation].should == memoized_hash_representation
            topic[:hash_representation].should_not equal(memoized_hash_representation)
          end
        end
      end

      context "when not #retained?" do
        describe "#hash_representation" do
          it "returns a class name => id => attributes Hash of the exposed objects" do
            topic.hash_representation.should == {
              "Account" => {
                "corey_account" => topic.accounts.find("corey_account").hash_representation.stringify_keys,
              },
              "Team" => {
                "mangos" => Team.find("mangos").hash_representation.stringify_keys,
              },
              "User" => {
                "nathan" => subject.fans.find("nathan").hash_representation.stringify_keys,
                "jan" => subject.fans.find("jan").hash_representation.stringify_keys
              }
            }
          end
        end

        describe "#json_representation" do
          it "returns #hash_representation.to_json" do
            JSON.parse(topic.json_representation).should == JSON.parse(topic.hash_representation.to_json)
          end
        end
      end
    end
  end
end
