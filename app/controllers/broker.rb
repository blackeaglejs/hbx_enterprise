class HbxEnterprise::App
  post '/brokers/legacy_xml' do
    @cv_hash = Parsers::Xml::Cv::IndividualParser.parse(request.body.read).to_hash

    file_path = ""
    broker_xml = render "brokers/legacy_broker", :locals =>{ :individual=> @cv_hash }
    File.open(file_path, 'a') { |file| file.write(broker_xml) }
  end
end