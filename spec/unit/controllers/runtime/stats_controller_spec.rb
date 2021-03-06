require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::StatsController do
    describe "GET /v2/apps/:id/stats" do
      before :each do
        @app = AppFactory.make(:package_hash => "abc", :package_state => "STAGED")
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
        @auditor = make_auditor_for_space(@app.space)
      end

      context 'when the client can see stats' do
        let(:stats) do
          {
            0 => {
              :state => "RUNNING",
              :stats => "mock stats",
            },
            1 => {
              :state => "DOWN",
              :since => 1,
            }
          }
        end
        let(:instances_reporter) { double(:instances_reporter) }

        before do
          instances_reporter_factory = CloudController::DependencyLocator.instance.instances_reporter_factory
          allow(instances_reporter_factory).to receive(:instances_reporter_for_app).and_return(instances_reporter)

          allow(instances_reporter).to receive(:stats_for_app).and_return(stats)
        end

        context 'because they are a developer' do
          it "should return the stats" do
            @app.state = "STARTED"
            @app.instances = 1
            @app.save

            @app.refresh

            expected = {
              "0" => {
                "state" => "RUNNING",
                "stats" => "mock stats",
              },
              "1" => {
                "state" => "DOWN",
                "since" => 1,
              }
            }

            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@developer))

            last_response.status.should == 200
            Yajl::Parser.parse(last_response.body).should == expected
            expect(instances_reporter).to have_received(:stats_for_app).with(
                                            satisfy { |requested_app| requested_app.guid == @app.guid })
          end
        end

        context 'because they are an auditor' do
          it "should return the stats" do
            @app.state = "STARTED"
            @app.instances = 1
            @app.save

            @app.refresh

            expected = {
              "0" => {
                "state" => "RUNNING",
                "stats" => "mock stats",
              },
              "1" => {
                "state" => "DOWN",
                "since" => 1,
              }
            }

            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@auditor))

            last_response.status.should == 200
            Yajl::Parser.parse(last_response.body).should == expected
            expect(instances_reporter).to have_received(:stats_for_app).with(
                                            satisfy { |requested_app| requested_app.guid == @app.guid })
          end
        end

        context 'when there is an error finding instances' do
          before do
            allow(instances_reporter).to receive(:stats_for_app).and_raise(VCAP::Errors::ApiError.new_from_details('StatsError', 'msg'))
          end

          it 'returns 400' do
            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@developer))

            last_response.status.should == 400
          end
        end

        context 'when the app is stopped' do
          before do
            @app.stop!
          end

          it 'raises an error' do
            get("/v2/apps/#{@app.guid}/stats", {}, headers_for(@developer))

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match("Stats error: Request failed for app: #{@app.name} as the app is in stopped state.")
          end
        end
      end

      context 'when the client cannot see stats' do
        context 'because they are a user' do
          it "should return 403" do
            get("/v2/apps/#{@app.guid}/stats",
                {},
                headers_for(@user))

            last_response.status.should == 403
          end
        end
      end
    end
  end
end
