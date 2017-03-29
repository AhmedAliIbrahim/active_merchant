require 'net/http'
require 'uri'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayfortGateway < Gateway
      self.test_url = 'https://sbpaymentservices.payfort.com/FortAPI/paymentApi'
      self.live_url = 'https://paymentservices.payfort.com/FortAPI/paymentApi'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.example.net/'
      self.display_name = 'New Gateway'

      STANDARD_ERROR_CODE_MAPPING = {}
      
      def self.hash_class
        defined?(ActiveSupport::HashWithIndifferentAccess) ? ActiveSupport::HashWithIndifferentAccess : Hash
      end
      
      private_class_method :hash_class
      
      def self.symbol_lookup(hash)
        hash_class[hash.map{|k,v| [k, v.parameterize.underscore.to_sym] }]
      end
      
      def self.reverse_symbol_lookup(hash)
        hash_class[hash.map{|k,v| [v, k]}]
      end
      
      STATUS_MAPPING = {
        "00"=>:invalid_request,
        "01"=>:order_stored,
        "02"=>:authorization_success,
        "03"=>:authorization_failed,
        "04"=>:capture_success,
        "05"=>:capture_failed,
        "06"=>:refund_success,
        "07"=>:refund_failed,
        "08"=>:authorization_voided_successfully,
        "09"=>:authorization_void_failed,
        "10"=>:incomplete,
        "11"=>:check_status_failed,
        "12"=>:check_status_success,
        "13"=>:purchase_failure,
        "14"=>:purchase_success,
        "15"=>:uncertain_transaction,
        "17"=>:tokenization_failed,
        "18"=>:tokenization_success,
        "19"=>:transaction_pending,
        "20"=>:on_hold,
        "21"=>:sdk_token_creation_failure,
        "22"=>:sdk_token_creation_success,
        "23"=>:failed_to_process_digital_wallet_service,
        "24"=>:digital_wallet_order_processed_successfully,
        "27"=>:check_card_balance_failed,
        "28"=>:check_card_balance_success,
        "29"=>:redemption_failed,
        "30"=>:redemption_success,
        "31"=>:reverse_redemption_transaction_failed,
        "32"=>:reverse_redemption_transaction_success,
        "40"=>:transaction_in_review,
        "42"=>:currency_conversion_success,
        "43"=>:currency_conversion_failed
      }
      
      REVERSE_STATUS_MAPPING = reverse_symbol_lookup(STATUS_MAPPING)
      
      MESSAGE_MAPPING = {
        "000"=>:success,
        "001"=>:missing_parameter,
        "002"=>:invalid_parameter_format,
        "003"=>:payment_option_is_not_available_for_this_merchant_s_account,
        "004"=>:invalid_command,
        "005"=>:invalid_amount,
        "006"=>:technical_problem,
        "007"=>:duplicate_order_number,
        "008"=>:signature_mismatch,
        "009"=>:invalid_merchant_identifier,
        "010"=>:invalid_access_code,
        "011"=>:order_not_saved,
        "012"=>:card_expired,
        "013"=>:invalid_currency,
        "014"=>:inactive_payment_option,
        "015"=>:inactive_merchant_account,
        "016"=>:invalid_card_number,
        "017"=>:operation_not_allowed_by_the_acquirer,
        "018"=>:operation_not_allowed_by_processor,
        "019"=>:inactive_acquirer,
        "020"=>:processor_is_inactive,
        "021"=>:payment_option_deactivated_by_acquirer,
        "023"=>:currency_not_accepted_by_acquirer,
        "024"=>:currency_not_accepted_by_processor,
        "025"=>:processor_integration_settings_are_missing,
        "026"=>:acquirer_integration_settings_are_missing,
        "027"=>:invalid_extra_parameters,
        "029"=>:insufficient_funds,
        "030"=>:authentication_failed,
        "031"=>:invalid_issuer,
        "032"=>:invalid_parameter_length,
        "033"=>:parameter_value_not_allowed,
        "034"=>:operation_not_allowed,
        "035"=>:order_created_successfully,
        "036"=>:order_not_found,
        "037"=>:missing_return_url,
        "039"=>:no_active_payment_option_found,
        "040"=>:invalid_transaction_source,
        "042"=>:operation_amount_exceeds_the_authorized_amount,
        "043"=>:inactive_operation,
        "044"=>:token_name_does_not_exist,
        "046"=>:channel_is_not_configured_for_the_selected_payment_option,
        "047"=>:order_already_processed,
        "048"=>:operation_amount_exceeds_captured_amount,
        "049"=>:operation_not_valid_for_this_payment_option,
        "050"=>:merchant_per_transaction_limit_exceeded,
        "051"=>:technical_error,
        "052"=>:consumer_is_not_in_olp_database,
        "053"=>:merchant_is_not_found_in_olp_engine_db,
        "054"=>:transaction_cannot_be_processed_at_this_moment,
        "055"=>:olp_id_alias_is_not_valid_please_contact_your_bank,
        "056"=>:olp_id_alias_does_not_exist_please_enter_a_valid_olp_id_alias,
        "057"=>:transaction_amount_exceeds_the_daily_transaction_limit,
        "058"=>:transaction_amount_exceeds_the_per_transaction_limit,
        "059"=>:merchant_name_and_sadad_merchant_id_do_not_match,
        "060"=>:the_entered_olp_password_is_incorrect_please_provide_a_valid_password,
        "062"=>:token_has_been_created,
        "063"=>:token_has_been_updated,
        "064"=>:"3_d_secure_check_requested",
        "065"=>:transaction_waiting_for_customer_s_action,
        "066"=>:merchant_reference_already_exists,
        "067"=>:dynamic_descriptor_not_configured_for_selected_payment,
        "068"=>:sdk_service_is_inactive,
        "069"=>:mapping_not_found_for_the_given_error_code,
        "070"=>:device_id_mismatch,
        "071"=>:failed_to_initiate_connection,
        "072"=>:transaction_has_been_cancelled_by_the_consumer,
        "073"=>:invalid_request_format,
        "074"=>:transaction_failed,
        "075"=>:transaction_failed,
        "076"=>:transaction_not_found_in_olp,
        "077"=>:error_transaction_code_not_found,
        "078"=>:failed_to_check_fraud_screen,
        "079"=>:transaction_challenged_by_fraud_rules,
        "080"=>:invalid_payment_option,
        "082"=>:inactive_fraud_service,
        "083"=>:unexpected_user_behavior,
        "084"=>:transaction_amount_is_either_bigger_than_maximum_or_less_than_minimum_amount_accepted_for_the_selected_plan,
        "086"=>:installment_plan_is_not_configured_for_merchant_account,
        "087"=>:card_bin_does_not_match_accepted_issuer_bank,
        "088"=>:token_name_was_not_created_for_this_transaction,
        "090"=>:transaction_in_review,
        "092"=>:invalid_issuer_code,
        "093"=>:service_inactive,
        "094"=>:invalid_plan_code,
        "095"=>:inactive_issuer,
        "096"=>:inactive_plan,
        "097"=>:operation_not_allowed_for_service,
        "098"=>:invalid_or_expired_call_id,
        "099"=>:failed_to_execute_service,
        "100"=>:invalid_expiry_date,
        "103"=>:duplicate_invoice_number,
        "110"=>:contradicting_parameters_please_refer_to_the_integration_guide,
        "111"=>:service_not_applicable_for_payment_option,
        "112"=>:service_not_applicable_for_payment_operation,
        "113"=>:service_not_applicable_for_e_commerce_indicator,
        "114"=>:token_already_exist,
        "246"=>:issue_related_to_migs_services,
        "662"=>:operation_not_allowed_the_specified_order_is_not_confirmed_yet,
        "666"=>:transaction_declined,
        "773"=>:transaction_closed,
        "777"=>:the_transaction_has_been_processed_but_failed_to_receive_confirmation,
        "778"=>:session_timed_out,
        "779"=>:transformation_error,
        "780"=>:transaction_number_transformation_error,
        "781"=>:message_or_response_code_transformation_error,
        "783"=>:installments_service_inactive,
        "784"=>:transaction_still_processing_you_can_t_make_another_transaction,
        "785"=>:transaction_blocked_by_fraud_check,
        "787"=>:failed_to_authenticate_the_user
      }
      
      REVERSE_MESSAGE_MAPPING = reverse_symbol_lookup(MESSAGE_MAPPING)
      
      
      def status_code_for(status_symbol)
        REVERSE_STATUS_MAPPING[status_symbol]
      end
      def message_code_for(message_symbol)
        REVERSE_MESSAGE_MAPPING[message_symbol]
      end
      
      RESPONSE_CODE_REGEX = /(?<status>[0-9]{2})(?<message>[0-9]{3})/
      def translate_response_code(response_code)
        match = RESPONSE_CODE_REGEX.match(response_code)
        status = match["status"]
        message = match["message"]
        {
          status_code: status,
          message_code: message,
          status_symbol: STATUS_MAPPING[status],
          message_symbol: MESSAGE_MAPPING[message]
        }
      end
      

      def initialize(options={})
        requires!(options, :sha_passphrase, :sha_passphrase_response, :access_code, :merchant_identifier, :sha, :return_url)
        super
      end
      
      def gateway
        PAYFORT_GATEWAY
      end
      
      def sign_back(params)
        params_to_sign = hash_class_i.new(params)
        sign_with_key(params_to_sign.except(*common_signature_ignored_params), @options[:sha_passphrase_response])
      end
      
      def sign(params)
        params_to_sign = hash_class_i.new(params)
        sign_with_key(params_to_sign.except(
              *common_signature_ignored_params, 
              :card_number, 
              :expiry_date, 
              :card_holder_name,
              :remember_me ), @options[:sha_passphrase])
      end
      
      def sign_with_key(params, key)
        string_to_digest = params.sort { |a, b| a[0].upcase <=> b[0].upcase }.map { |k, v| "#{k}=#{v}" }.join()
        string_to_digest = "#{key}#{string_to_digest}#{key}"
        "Digest::#{@options[:sha].upcase}".constantize.hexdigest(string_to_digest)
      end
      
      def check_for_successful_tokenization(status)
        translate_response_code(status)[:status_symbol] == :tokenization_success
      end
      
      def check_for_successful_purchase(status)
        translate_response_code(status)[:status_symbol] == :successful_purchase
      end
      
      def check_authorize_status(amount, merchant_reference, fort_id)
        params = check_status_params('CHECK_STATUS', merchant_reference, fort_id)
        commit(params, amount)
      end
      
      def purchase(token, amount, email, id, card_security_code, remember_me, customer_ip)
        params = request_params('PURCHASE', id, amount, email, token, card_security_code, remember_me, false, customer_ip)
        commit(params)
      end
      
      def recurring(token, amount, email, id, card_security_code, remember_me)
        params = request_params('PURCHASE', id, (amount/100), email, token, card_security_code, remember_me, true)
        commit(params)
      end
      
      def refund(money, authorization, options = {})
        params = refund_capture_void_params(money, authorization, 'REFUND')
        commit(params)
      end
      
      def authorize(token, amount, email, id, card_security_code, remember_me, customer_ip)
        params = request_params('AUTHORIZATION', id, amount, email, token, card_security_code, remember_me, false, customer_ip)
        commit(params)
      end

      def capture(money, authorization, options = {})
        params = refund_capture_void_params(money, authorization, 'CAPTURE')
        commit(params)
      end

      def void(authorization, options={})
        params = refund_capture_void_params(nil,authorization, 'VOID_AUTHORIZATION' )
        commit(params)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private
      
      def success?(response, options = nil)
        result = translate_response_code(response["response_code"])
        if response["command"] == "CAPTURE"
          result[:status_symbol] == :capture_success && result[:message_symbol] == :success
        elsif response["command"] == "AUTHORIZATION"
          result[:status_symbol] == :on_hold && result[:message_symbol] == :"3_d_secure_check_requested"
        elsif response["command"] == "VOID_AUTHORIZATION"
          result[:status_symbol] == :authorization_voided_successfully && result[:message_symbol] == :success
        elsif response["command"] == "REFUND"
          result[:status_symbol] == :refund_success && result[:message_symbol] == :success
        elsif response["query_command"] == "CHECK_STATUS"
          result[:status_symbol] == :check_status_success && result[:message_symbol] == :success && response["authorized_amount"] == options.to_s
        elsif response["command"] == "PURCHASE"
          result[:status_symbol] == :purchase_success && result[:message_symbol] == :success
        end
      end
      
      def hash_class_i
        defined?(ActiveSupport::HashWithIndifferentAccess) ? ActiveSupport::HashWithIndifferentAccess : Hash
      end
      
      def common_signature_ignored_params
        [:signature, :integration_type, :"3ds", :r]
      end
      
      def url
        test? ? test_url : live_url
      end
      
      def header
        {
          'Content-Type': 'application/json'
        }
      end
      
      def commit(params, options = nil)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = params.to_json
        response = http.request(request)
        response = JSON.parse(response.body)
        Response.new(success?(response, options),
                     response["response_message"],
                     response)
      end
      
      def common_params
        params = {
          access_code: @options[:access_code],
          merchant_identifier: @options[:merchant_identifier],
          language: 'en',
          currency: 'AED',
          return_url: @options[:return_url],
        }
      end
      
      def request_params(command, order_id, amount, email, token, card_security_code, remember_me, recurring = false, customer_ip = nil)
        params = {
          command: command,
          merchant_reference: order_id,
          amount: Integer(amount*100),
          customer_email: email,
          token_name: token,
        }
        params.merge!(common_params)
        params.merge!(customer_ip: customer_ip) if customer_ip.present?
        params.merge!(card_security_code: card_security_code) if card_security_code.present?
        params.merge!(remember_me: remember_me) if remember_me.present?
        params.merge!(eci: 'RECURRING') if recurring
        signature = sign(params)
        params.merge!(signature: signature)
      end
      
      
      def check_status_params(command, merchant_reference, fort_id)
        params = {
          query_command: command,
          merchant_reference: "#{merchant_reference}",
          fort_id: fort_id
        }
        params.merge!(common_params)
        params.delete(:return_url)
        params.delete(:currency)
        signature = sign(params)
        params.merge!(signature: signature)
      end
      
      def refund_capture_void_params(amount, fort_id, command)
        
        params = {
          command: command,
        }
        params.merge!(amount: amount) if command != 'VOID_AUTHORIZATION'
        params.merge!(fort_id: fort_id) if command != 'VOID_AUTHORIZATION'
        params.merge!(merchant_reference: fort_id) if command == 'VOID_AUTHORIZATION'
        params.merge!(common_params)
        params.delete(:return_url)
        params.delete(:currency) if command == 'VOID_AUTHORIZATION'
        signature = sign(params)
        params.merge!(signature: signature)
      end
      
    end
  end
end
