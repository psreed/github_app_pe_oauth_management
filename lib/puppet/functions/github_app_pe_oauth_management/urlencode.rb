Puppet::Functions.create_function(:'github_app_pe_oauth_management::urlencode') do
  dispatch :encode do
    param 'String', :input
  end

  def encode(input)
    require 'erb'
    ERB::Util.url_encode(input)
  end
end