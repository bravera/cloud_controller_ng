require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BillingEventsController do
    describe "permissions" do
      context "with 5 event records" do
        let(:org) do
          Organization.make
        end

        let(:org_admin_headers) do
          user = User.make
          org.add_user(user)
          org.add_manager(user)
          headers_for(user)
        end

        before do
          BillingEvent.plugin :scissors
          BillingEvent.delete

          timestamp = Time.new(2012, 01, 01, 00, 00, 01)
          @start_time = timestamp

          @org_event = OrganizationStartEvent.make(
            :timestamp => timestamp
          )

          @app_start_event = AppStartEvent.make(
            :timestamp => timestamp += 1
          )

          @app_stop_event = AppStopEvent.make(
            :timestamp => timestamp += 1
          )

          @service_create_event = ServiceCreateEvent.make(
            :timestamp => timestamp += 1
          )

          @service_delete_event = ServiceDeleteEvent.make(
            :timestamp => timestamp += 1
          )

          @end_time = timestamp
        end

        describe 'GET /v2/billing_events' do
          it "should return 400" do
            get "/v2/billing_events", {}, admin_headers
            last_response.status.should == 400
          end

          it "should be deprecated" do
            get "/v2/billing_events", {}, admin_headers
            expect(last_response).to be_a_deprecated_response
          end
        end

        describe 'GET /v2/billing_events?start_date=#{start_date}' do
          it "should return 400" do
            get "/v2/billing_events?start_date=#{@start_time.iso8601}", {}, admin_headers
            last_response.status.should == 400
          end

          it "should be deprecated" do
            get "/v2/billing_events?start_date=#{@start_time.iso8601}", {}, admin_headers
            expect(last_response).to be_a_deprecated_response
          end
        end

        describe 'GET /v2/billing_events?start_date=bogus' do
          it "should return 400" do
            get "/v2/billing_events?start_date=bogus", {}, admin_headers
            last_response.status.should == 400
          end
        end

        describe 'GET /v2/billing_events?end_date=bogus' do
          it "should return 400" do
            get "/v2/billing_events?end_date=bogus", {}, admin_headers
            last_response.status.should == 400
          end
        end

        describe 'GET /v2/billing_events?start_date=#{start_date}&end_date=#{end_date}' do
          let(:path) do
            "/v2/billing_events?" +
            "start_date=#{@start_time.utc.iso8601}" +
            "&end_date=#{@end_time.utc.iso8601}"
          end

          context "as a cf admin" do
            it "should return 200" do
              get path, {}, admin_headers
              last_response.status.should == 200
            end

            it "should return 5 records" do
              get path, {}, admin_headers
              decoded_response["total_results"].should == 5
              decoded_response["total_pages"].should == 1
              decoded_response["prev_url"].should == nil
              decoded_response["next_url"].should == nil
              decoded_response["resources"].size.should == 5
            end

            it "should correctly serialize the org billing start event" do
              get path, {}, admin_headers
              decoded_response["resources"][0].should == {
                "event_type" => "organization_billing_start",
                "organization_guid" => @org_event.organization_guid,
                "organization_name" => @org_event.organization_name,
                "timestamp" => @org_event.timestamp.iso8601,
              }
            end

            it "should correctly serialize the app start event" do
              get path, {}, admin_headers
              decoded_response["resources"][1].should == {
                "event_type" => "app_start",
                "organization_guid" => @app_start_event.organization_guid,
                "organization_name" => @app_start_event.organization_name,
                "space_guid" => @app_start_event.space_guid,
                "space_name" => @app_start_event.space_name,
                "app_guid" => @app_start_event.app_guid,
                "app_name" => @app_start_event.app_name,
                "app_run_id" => @app_start_event.app_run_id,
                "app_plan_name" => @app_start_event.app_plan_name,
                "app_memory" => @app_start_event.app_memory,
                "app_instance_count" => @app_start_event.app_instance_count,
                "timestamp" => @app_start_event.timestamp.iso8601,
              }
            end

            it "should correctly serialize the app stop event" do
              get path, {}, admin_headers
              decoded_response["resources"][2].should == {
                "event_type" => "app_stop",
                "organization_guid" => @app_stop_event.organization_guid,
                "organization_name" => @app_stop_event.organization_name,
                "space_guid" => @app_stop_event.space_guid,
                "space_name" => @app_stop_event.space_name,
                "app_guid" => @app_stop_event.app_guid,
                "app_name" => @app_stop_event.app_name,
                "app_run_id" => @app_stop_event.app_run_id,
                "timestamp" => @app_stop_event.timestamp.iso8601,
              }
            end

            it "should correctly serialize the service create event" do
              get path, {}, admin_headers
              decoded_response["resources"][3].should == {
                "event_type" => "service_create",
                "organization_guid" => @service_create_event.organization_guid,
                "organization_name" => @service_create_event.organization_name,
                "space_guid" => @service_create_event.space_guid,
                "space_name" => @service_create_event.space_name,
                "service_instance_guid" => @service_create_event.service_instance_guid,
                "service_instance_name" => @service_create_event.service_instance_name,
                "service_guid" => @service_create_event.service_guid,
                "service_label" => @service_create_event.service_label,
                "service_provider" => @service_create_event.service_provider,
                "service_version" => @service_create_event.service_version,
                "service_plan_guid" => @service_create_event.service_plan_guid,
                "service_plan_name" => @service_create_event.service_plan_name,
                "timestamp" => @service_create_event.timestamp.iso8601,
              }
            end

            it "should correctly serialize the service delete event" do
              get path, {}, admin_headers
              decoded_response["resources"][4].should == {
                "event_type" => "service_delete",
                "organization_guid" => @service_delete_event.organization_guid,
                "organization_name" => @service_delete_event.organization_name,
                "space_guid" => @service_delete_event.space_guid,
                "space_name" => @service_delete_event.space_name,
                "service_instance_guid" => @service_delete_event.service_instance_guid,
                "service_instance_name" => @service_delete_event.service_instance_name,
                "timestamp" => @service_delete_event.timestamp.iso8601,
              }
            end
          end

          context "as an org admin" do
            it "should return 200" do
              get path, {}, org_admin_headers
              last_response.status.should == 200
            end

            it "should return 0 records" do
              get path, {}, org_admin_headers
              decoded_response["total_results"].should == 0
              decoded_response["resources"].size.should == 0
            end
          end
        end

        describe 'GET /v2/billing_events?start_date=#{start_date}&end_date=#{end_date-1}' do
          let(:path) do
            "/v2/billing_events?" +
            "start_date=#{@start_time.iso8601}" +
            "&end_date=#{(@end_time-1).iso8601}"
          end

          it "should return 200" do
            get path, {}, admin_headers
            last_response.status.should == 200
          end

          it "should return 4 records" do
            get path, {}, admin_headers
            decoded_response["total_results"].should == 4
            decoded_response["total_pages"].should == 1
            decoded_response["prev_url"].should == nil
            decoded_response["next_url"].should == nil
            decoded_response["resources"].size.should == 4
          end
        end

        describe 'GET /v2/billing_events?start_date=#{start_date+1}&end_date=#{end_date}' do
          let(:path) do
            "/v2/billing_events?" +
            "start_date=#{(@start_time+1).iso8601}" +
            "&end_date=#{@end_time.iso8601}"
          end

          it "should return 200" do
            get path, {}, admin_headers
            last_response.status.should == 200
          end

          it "should return 4 records" do
            get path, {}, admin_headers
            decoded_response["total_results"].should == 4
            decoded_response["total_pages"].should == 1
            decoded_response["prev_url"].should == nil
            decoded_response["next_url"].should == nil
            decoded_response["resources"].size.should == 4
          end
        end

        describe 'GET /v2/billing_events?start_date=#{start_date+1}&end_date=#{end_date-1}' do
          let(:path) do
            "/v2/billing_events?" +
            "start_date=#{(@start_time+1).iso8601}" +
            "&end_date=#{(@end_time-1).iso8601}"
          end

          it "should return 200" do
            get path, {}, admin_headers
            last_response.status.should == 200
          end

          it "should return 3 records" do
            get path, {}, admin_headers
            decoded_response["total_results"].should == 3
            decoded_response["total_pages"].should == 1
            decoded_response["prev_url"].should == nil
            decoded_response["next_url"].should == nil
            decoded_response["resources"].size.should == 3
          end
        end
      end
    end
  end
end
