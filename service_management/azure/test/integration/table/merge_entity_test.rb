#-------------------------------------------------------------------------
# # Copyright (c) Microsoft and contributors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#--------------------------------------------------------------------------

require "integration/test_helper"
require "azure/table/table_service"
require "azure/core/http/http_error"

describe Azure::Table::TableService do
  describe "#merge_entity" do
    subject { Azure::Table::TableService.new }
    let(:table_name){ TableNameHelper.name }

    let(:entity_properties){
      {
        "PartitionKey" => "testingpartition",
        "RowKey" => "abcd1234_existing",
        "CustomStringProperty" => "CustomPropertyValue",
        "CustomIntegerProperty" => 37,
        "CustomBooleanProperty" => true,
        "CustomDateProperty" => Time.now
      }
    }

    before {
      subject.create_table table_name
      subject.insert_entity table_name, entity_properties
      @existing_etag = ""

      exists = false
      begin
        existing = subject.get_entity table_name, entity_properties["PartitionKey"], entity_properties["RowKey"]
        @existing_etag = existing.etag
        exists = true
      rescue
      end

      assert exists, "cannot verify existing record"
    }

    after { TableNameHelper.clean }

    it "updates an existing entity, merging the properties" do
      etag = subject.merge_entity table_name, {
        "PartitionKey" => entity_properties["PartitionKey"],
        "RowKey" => entity_properties["RowKey"],
        "NewCustomProperty" => "NewCustomValue"
      }
      etag.must_be_kind_of String
      etag.wont_equal @existing_etag

      result = subject.get_entity table_name, entity_properties["PartitionKey"], entity_properties["RowKey"]

      result.must_be_kind_of Azure::Table::Entity
      result.table.must_equal table_name
      result.properties["PartitionKey"].must_equal entity_properties["PartitionKey"]
      result.properties["RowKey"].must_equal entity_properties["RowKey"]

      # retained all existing props
      entity_properties.each { |k,v|
        unless entity_properties[k].class == Time
          result.properties[k].must_equal entity_properties[k]
        else
          result.properties[k].to_i.must_equal entity_properties[k].to_i
        end
      }

      # and has the new one
      result.properties["NewCustomProperty"].must_equal "NewCustomValue"
    end

    it "errors on a non-existing row key" do
      assert_raises(Azure::Core::Http::HTTPError) do
        entity = entity_properties.dup
        entity["RowKey"] = "this-row-key-does-not-exist"
        subject.merge_entity table_name, entity
      end
    end

    it "errors on an invalid table name" do
      assert_raises(Azure::Core::Http::HTTPError) do
        subject.merge_entity "this_table.cannot-exist!", entity_properties
      end
    end

    it "errors on an invalid partition key" do
      assert_raises(Azure::Core::Http::HTTPError) do
        entity = entity_properties.dup
        entity["PartitionKey"] = "this/partition_key#is?invalid"
        subject.merge_entity table_name, entity
      end
    end

    it "errors on an invalid row key" do
      assert_raises(Azure::Core::Http::HTTPError) do
        entity = entity_properties.dup
        entity["RowKey"] = "this/row_key#is?invalid"
        subject.merge_entity table_name, entity
      end
    end
  end
end