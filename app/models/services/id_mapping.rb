module Services
  class IdMapping
    XML_NSES = {
      :hbx_res => "http://xmlns.oracle.com/DCAS/edi/GetDCASIDPersonID"
    }

    def self.from_person_id(id)
      map = self.from_person_ids([id])
      map[id]
    end

    def self.from_person_ids(ids)
      lookup_response = Proxies::HbxIdMappingRequest.request(ids)
      map_hbx_id_results(lookup_response)
    end

    def self.to_person_ids(ids)
      lookup_response = Proxies::PersonIdMappingRequest.request(ids)
      map_person_id_results(lookup_response)
    end

    def self.map_hbx_id_results(response)
      xml = Nokogiri::XML(response)
      map = {}
      xml.xpath("//hbx_res:DCASIDPersonIDList", XML_NSES).each do |node|
        p_id = node.xpath("hbx_res:PersonID", XML_NSES).first.text
        hbx_id = node.xpath("hbx_res:DCASID", XML_NSES).first.text
        map[p_id] = hbx_id
      end
      map
    end

    def self.map_person_id_results(response)
      xml = Nokogiri::XML(response)
      map = {}
      xml.xpath("//hbx_res:DCASIDPersonIDList", XML_NSES).each do |node|
        p_id = node.xpath("hbx_res:PersonID", XML_NSES).first.text
        hbx_id = node.xpath("hbx_res:DCASID", XML_NSES).first.text
        map[hbx_id] = p_id
      end
      map
    end
  end
end
