# Resource: commvault_instance

include CommVault::Api
include CommVault::Cache
include CommVault::Helpers

resource_name :commvault_fs_subclient

default_action :configure

# Properties
property :endpoint, String
property :subclient_name, String, default: 'default'
property :filters, Array, default: []
property :use_cache, [true, false], default: true
property :cache_timeout, Integer, default: 43200 # 12 hours
property :use_local_login, [true, false], default: true
property :login_user, String
property :login_pass, String

action :configure do
  raise 'Unable to configure a subclient if there is no Instance001 installed' unless cvlt_already_installed?
  unless new_resource.use_local_login
    raise 'User/Pass combo cannot be empty' if new_resource.login_user.nil? || new_resource.login_pass.nil?
  end

  entry = "subclient::#{new_resource.subclient_name}"

  # Cache is stored on disk and needs to be loaded, will be available in node['commvault']['cache']
  cache_load

  if new_resource.use_cache && cache_exists(entry, new_resource.filters)

    last_set = cache_get_timestamp(entry)
    unless last_set.nil?
      diff = Time.now.getutc.to_i - last_set.to_i
      Chef::Log.debug "Signatures in cache match. Diff: #{diff}, timeout: #{new_resource.cache_timeout}"
      if diff <= new_resource.cache_timeout
        Chef::Log.info 'Cache valid, not doing anything'
        return
      end
    end
  end

  api_token = if new_resource.use_local_login
                # Get the api token using qlogin --localadmin
                cv_token_local
              else
                # Get the api token using login to the API
                cv_token_api(new_resource.endpoint, new_resource.login_user, new_resource.login_pass)
              end

  Chef::Log.debug "Token: [#{api_token}]"

  # License the File System Agent if not licensed
  cv_fs_reconfigure(new_resource.endpoint, api_token) unless cv_fs_licensed(new_resource.endpoint, api_token)

  # Configure the subclient
  cv_fs_filter(new_resource.endpoint, api_token, new_resource.subclient_name, new_resource.filters)

  # Cache
  if new_resource.use_cache
    cache_save(entry, new_resource.filters)
  end

  Chef::Log.debug "Contents of saved cache: [#{node['commvault']['cache']}]"
end
