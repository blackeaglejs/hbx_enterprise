module ManualEnrollments
  class EnrollmentRowBuilder

    attr_accessor :data_set
    MAX_ENROLLEES = 9

    def initialize(enrollment, is_shop)
      @data_set = []
      @enrollment = enrollment
      @is_shop = is_shop
    end

    def to_csv
      hbx_enrollment = @enrollment.policy.hbx_enrollment
      append_enrollment_type
      append_market
      append_employer(hbx_enrollment)
      append_broker
      append_begin_date
      append_plan_name(hbx_enrollment.plan)
      append_qhp_id
      append_csr_info
      append_csr_varient
      append_plan_hios(hbx_enrollment.plan)
      append_premium(hbx_enrollment)
      append_aptc(hbx_enrollment)
      append_responsible_amount(hbx_enrollment)
      append_enrollees
      @data_set
    end

    def append_enrollment_type
      @data_set << 'New Enrollment'
    end

    def append_market
      @data_set << (@is_shop ? 'Shop' : 'IVL')
    end

    def append_employer(hbx_enrollment)
      if hbx_enrollment.shop_market
        @data_set << hbx_enrollment.shop_market.employer_name
        @data_set << strip_uri(hbx_enrollment.shop_market.employer_fein)
      else
        2.times { append_blank }
      end
    end

    def append_broker
      broker = @enrollment.policy.broker
      if broker.nil?
        2.times { append_blank }
      else
        @data_set << broker.name
        @data_set << broker.broker_npn
      end
    end

    def append_begin_date
      subscriber = sort_enrollees_by_rel(@enrollment.policy.enrollees).first
      @data_set << format_date(subscriber.begin_date)
    end

    def append_plan_name(plan)
      @data_set << plan.name
    end

    def append_plan_hios(plan)
      @data_set << strip_uri(plan.hios_id)
    end

    def append_qhp_id
      append_blank
    end
  
    def append_csr_info
      append_blank
    end

    def append_csr_varient
      append_blank
    end

    def append_premium(hbx_enrollment)
      @data_set << hbx_enrollment.premium_total_amount
    end

    def append_aptc(hbx_enrollment)
      if hbx_enrollment.shop_market
        @data_set << hbx_enrollment.shop_market.employer_responsible_amount
      else
        @data_set << hbx_enrollment.individual_market.applied_aptc_amount
      end
    end

    def append_responsible_amount(hbx_enrollment)
      @data_set << hbx_enrollment.total_responsible_amount
    end

    def append_demographics(enrollee)
      demographics = enrollee.member.person_demographics
      @data_set << demographics.ssn
      @data_set << format_date(demographics.birth_date)
      @data_set << strip_uri(demographics.sex)
    end

    def append_enrollee_preimum(enrollee)
      @data_set << enrollee.premium_amount
    end

    def append_names(enrollee)
      person = enrollee.member.person
      @data_set << person.name_first
      @data_set << person.name_middle
      @data_set << person.name_last
    end

    def append_email(enrollee)
      person = enrollee.member.person
      if person.emails[0].nil?
        append_blank
      else
        @data_set << person.emails[0].email_address
      end
    end

    def append_phone(enrollee)
      person = enrollee.member.person
      if person.phones[0].nil?
        append_blank
      else 
        @data_set << person.phones[0].full_phone_number
      end
    end

    def append_address(enrollee)
      address = enrollee.member.person.addresses[0]
      if address.nil?
        5.times { append_blank }
      else
        @data_set << address.address_line_1
        @data_set << address.address_line_2
        @data_set << address.location_city_name
        @data_set << address.location_state_code
        @data_set << address.postal_code
      end
    end

    def append_relationship(enrollee)
      @data_set << relationship(enrollee)
    end

    def append_blank_enrollee
      15.times { append_blank }
    end

    def append_enrollees
      sort_enrollees_by_rel(@enrollment.policy.enrollees).each do |enrollee|
        append_demographics(enrollee)
        append_enrollee_preimum(enrollee)
        append_names(enrollee)
        append_email(enrollee)
        append_phone(enrollee)
        append_address(enrollee)
        append_relationship(enrollee)
      end

      (MAX_ENROLLEES - @enrollment.policy.enrollees.size).times { append_blank_enrollee } 
    end

    def sort_enrollees_by_rel(enrollees)
      relationships = ['self', 'spouse', 'child']

      enrollees.select{ |enrollee|
        relationships.include?(relationship(enrollee))
      }.sort_by{ |enrollee|
          relationships.index(relationship(enrollee))
      } + enrollees.reject{ |enrollee|
        relationships.include?(relationship(enrollee))
      }
    end

    def relationship(enrollee)
      if enrollee.member.relationship_uri.blank? && enrollee.is_subscriber == "true"
        return 'self'
      end
      strip_uri(enrollee.member.relationship_uri).downcase
    end

    private

    def append_blank
      @data_set << nil
    end

    def format_date(date)
      return nil if date.nil?
      Date.parse(date).strftime("%m/%d/%Y")
    end

    def strip_uri(text)
      if text.blank?
        return text.to_s
      end
      text.split('#')[1]
    end
  end
end
