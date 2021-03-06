class ExchangeInformation

  class MissingKeyError < StandardError
    def initialize(key)
      super("Missing required key: #{key}") 
    end
  end

  include Singleton

  REQUIRED_KEYS = [
    'amqp_uri',
    'hbx_id', 'environment', 'receiver_id',
    'osb_host', 'osb_username', 'osb_password', 'osb_nonce', 'osb_created',
    'invalid_argument_queue', 'processing_failure_queue', 'event_exchange', 'request_exchange', 'event_publish_exchange',
    'vlp_url', 'ssa_url', 'account_search_url', 'fars_url', 'ridp_url', 'account_creation_url', 'residency_url',
    'case_query_url'
  ]

  attr_reader :config

  # TODO: I have a feeling we may be using this pattern
  #       A LOT.  Look into extracting it if we repeat.
  def initialize
    @config = YAML.load_file(File.join(HbxEnterprise::App.root,'..','config', 'exchange.yml'))
    ensure_configuration_values(@config)
  end

  def ensure_configuration_values(conf)
    REQUIRED_KEYS.each do |k|
      if @config[k].blank?
        raise MissingKeyError.new(k)
      end
    end
  end

  def self.define_key(key)
    define_method(key.to_sym) do
      config[key.to_s]
    end
    self.instance_eval(<<-RUBYCODE)
      def self.#{key.to_s}
        self.instance.#{key.to_s}
      end
    RUBYCODE
  end

  REQUIRED_KEYS.each do |k|
    define_key k
  end

  def self.queue_name_for(klass)
    base_key = "#{self.hbx_id}.#{self.environment}.q.hbx_enterprise."
    base_key + klass.name.to_s.split("::").last.underscore
  end

  def self.use_soap_security?
    self.instance.use_soap_security?
  end

  def use_soap_security?
    @use_soap_security ||= extract_soap_security_setting
  end

  def extract_soap_security_setting
    config_val = config["use_soap_security"]
    return true if config_val.nil?
    !(config_val.to_s.downcase == "false")
  end
end
