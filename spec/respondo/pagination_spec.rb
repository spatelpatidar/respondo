# frozen_string_literal: true

require "spec_helper"

RSpec.describe Respondo::Pagination do
  describe ".extract" do
    it "returns nil for nil" do
      expect(described_class.extract(nil)).to be_nil
    end

    it "returns nil for a plain Array" do
      expect(described_class.extract([1, 2, 3])).to be_nil
    end

    it "returns nil for a plain Hash" do
      expect(described_class.extract({ a: 1 })).to be_nil
    end

    context "with a Kaminari-like collection" do
      let(:collection) do
        double("KaminariCollection",
          current_page: 2,
          limit_value:  10,
          total_pages:  5,
          total_count:  48,
          next_page:    3,
          prev_page:    1
        )
      end

      it "extracts pagination meta" do
        result = described_class.extract(collection)
        expect(result).to eq(
          current_page: 2,
          per_page:     10,
          total_pages:  5,
          total_count:  48,
          next_page:    3,
          prev_page:    1
        )
      end
    end

    context "with a WillPaginate-like collection" do
      let(:collection) do
        double("WPCollection",
          current_page:  1,
          per_page:      25,
          total_pages:   4,
          total_entries: 90,
          next_page:     2,
          previous_page: nil
        )
      end

      before do
        # WillPaginate does NOT respond to limit_value
        allow(collection).to receive(:respond_to?).with(:current_page).and_return(true)
        allow(collection).to receive(:respond_to?).with(:total_pages).and_return(true)
        allow(collection).to receive(:respond_to?).with(:per_page).and_return(true)
        allow(collection).to receive(:respond_to?).with(:limit_value).and_return(false)
      end

      it "extracts pagination meta" do
        result = described_class.extract(collection)
        expect(result).to eq(
          current_page: 1,
          per_page:     25,
          total_pages:  4,
          total_count:  90,
          next_page:    2,
          prev_page:    nil
        )
      end
    end
  end
end
