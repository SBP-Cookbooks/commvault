# Resource: commvault_instance

include CommVault::Api
include CommVault::Cache
include CommVault::Helpers

provides :commvault_fs_subclient

unified_mode true if respond_to? :unified_mode

default_action :configure

# Properties
property :endpoint, String
property :subclient_name, String, default: 'default'
property :filters, Array, default: []
property :use_cache, [true, false], default: true
property :cache_timeout, Integer, default: 43200 # 12 hours
property :use_local_login, [true, false], default: true
property :plan_name, [String, nil]
property :login_user, String
property :login_pass, String
property :systemstate, [true, false], default: true, required: false

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

  api_token = ''
  # Try 3 times (with 30 secs interval) to get the client id (SAFETY PRECAUTION)
  counter = 1
  loop do
    begin
      api_token = if new_resource.use_local_login
                    # Get the api token using qlogin --localadmin
                    cv_token_local
                  else
                    # Get the api token using login to the API
                    cv_token_api(new_resource.endpoint, new_resource.login_user, new_resource.login_pass)
                  end
      break
    rescue
      Chef::Log.warn "Unable to get token (counter: #{counter}), retrying after sleep of 30 seconds"
      sleep(30)
    end

    counter += 1
    if counter > 8
      Chef::Log.error 'Unable to obtain token from platform, bailing for this run'
      return
    end
  end

  Chef::Log.debug "Token: [#{api_token}]"

  begin
    cv_client_id(new_resource.endpoint, api_token)
  rescue
    Chef::Log.warn 'Unable to get client id'
    return
  end

  # Commvault does not "install" the file system agent anymore if the installation is done in restore only mode, so do it here
  cv_install_fs(new_resource.endpoint, api_token) unless cv_fs_installed(new_resource.endpoint, api_token)

  # License the File System Agent if not licensed
  cv_fs_reconfigure(new_resource.endpoint, api_token) unless cv_fs_licensed(new_resource.endpoint, api_token)

  unless cv_fs_subclient_has_plan(new_resource.endpoint, api_token, new_resource.subclient_name)
    if new_resource.plan_name.nil?
      Chef::Log.warn "Plan has not been assigned to subclient #{new_resource.subclient_name}, waiting for assignment"
      return
    else
      cv_fs_subclient_assign_plan(new_resource.endpoint, api_token, new_resource.subclient_name, new_resource.plan_name)
    end
  end

  # Configure the subclient
  cv_fs_filter(new_resource.endpoint, api_token, new_resource.subclient_name, new_resource.filters, new_resource.systemstate)

  # Cache
  if new_resource.use_cache
    cache_save(entry, new_resource.filters)
  end

  Chef::Log.debug "Contents of saved cache: [#{node['commvault']['cache']}]"
end
