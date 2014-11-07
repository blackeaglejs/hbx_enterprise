module Parsers
  module EnrollmentDetails
    class PlanParser

      def initialize(node)
        @xml = node
      end

      def plan_name
        @xml.at_xpath("plan/plan-name").text
      end

      def hios_id
        @xml.at_xpath("plan/plan-id").text
      end

      def dental?
        Maybe.new(@xml.at_xpath("plan/product-line")).text.downcase.value == "dental"
      end

      def premium_total
        Maybe.new(@xml.at_xpath("plan/premium")).text.value
      end

      def person_premiums
        results = {}
        @xml.xpath("plan/person-premiums/person-premium").each do |node|
          person_id = node.at_xpath("person-id").text
          value = node.at_xpath("premium").text
          results[person_id] = value
        end
        results
      end

      def self.build(xml_node)
        self.new(xml_node)
      end
    end
  end
end