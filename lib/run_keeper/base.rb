module RunKeeper
  class Base
    HEADERS = {
      'fitness_activities' => 'application/vnd.com.runkeeper.FitnessActivityFeed+json',
      'profile'            => 'application/vnd.com.runkeeper.Profile+json',
      'user'               => 'application/vnd.com.runkeeper.User+json'
    }

    def initialize client_id, client_secret
      @client_id, @client_secret = client_id, client_secret
    end

    def fitness_activities token, options = {}
      options[:params] = {}
      options[:start]  = options[:start] ? Time.utc(*options[:start].split('-')) : nil
      options[:finish] = options[:finish] ? Time.utc(*options[:finish].split('-'), 23, 59, 59) : Time.now.utc

      get_activities token, options
    end

    def profile token
      Profile.new request(token, 'profile').parsed.merge(:userid => @user.userid)
    end

    def request token, endpoint, params = {}
      response = access_token(token).get(user(token).send(endpoint), :headers => {'Accept' => HEADERS[endpoint]}, :parse => :json) do |request|
        request.params = params
      end
      parse_response response
    end

    def user token
      @user ||= User.new access_token(token).get('/user', :headers => {'Accept' => HEADERS['user']}, :parse => :json).parsed
    end

  private
    def access_token token
      client = OAuth2::Client.new @client_id, @client_secret, :site => 'https://api.runkeeper.com', :authorize_url => '/apps/authorize', :token_url => '/apps/token', :raise_errors => false
      OAuth2::AccessToken.new client, token
    end

    def get_activities token, options, activities = nil
      response   = request(token, 'fitness_activities', options[:params])
      activities = response.parsed['items'].map { |activity| Activity.new(activity) }
      
      if options[:start]
        activities -= activities.reject { |activity| (activity.start_time > options[:start]) && (activity.start_time < options[:finish]) }
      end

      if response.parsed['next']
        options[:params].update(:page => response.parsed['next'].split('=').last)
        activities + get_activities(token, options, activities)
      else
        activities
      end
    end

    def parse_response response
      if [200, 304].include? response.status
        response
      else
        raise Error.new(response)
      end
    end
  end
end
