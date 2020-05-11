# Cookbook:: commvault
# Library:: cache

require 'digest'
require 'time'
require 'json'

module CommVault
  module Cache
    def cache_load
      # We need to be 100% clear this cannot happen
      Chef::Log.warn 'We are overwriting node[commvault][cache], this could happen if you manage multiple subclients' if node.key?('commvault') && node['commvault'].key?('cache')

      cache_file = File.join(Chef::Config['file_cache_path'], 'commvault_cache.json')
      Chef::Log.debug "Cache file: [#{cache_file}]"
      node.default['commvault']['cache'] = if File.exist?(cache_file)
                                             JSON.parse(File.read(cache_file))
                                           else
                                             {}
                                           end
      Chef::Log.debug "Contents read from Cache:: [#{node['commvault']['cache']}]"
    end

    def cache_exists(entry, filters)
      # We absolutely require filters to be of type Array
      raise '[CommVault::Cache::cache_exists] input filters needs to be of type Array' unless filters.instance_of?(Array)

      if node.key?('commvault') && node['commvault'].key?('cache') && node['commvault']['cache'].key?(entry)
        curr_sig = Digest::SHA256.hexdigest(filters.join('::'))
        cache_sig = node['commvault']['cache'][entry]['signature']
        Chef::Log.debug "[CommVault] Cache found for entry [#{entry}], signatures: [#{cache_sig}] <=> [#{curr_sig}]"
        return curr_sig == cache_sig
      end

      # If we get here the node variables do not exist and we create them here
      node.default['commvault']['cache'][entry]['signature'] = nil
      Chef::Log.info "[CommVault] No cache found for [#{entry}]"
      false
    end

    def cache_get_timestamp(entry)
      if node.key?('commvault') && node['commvault'].key?('cache') && node['commvault']['cache'].key?(entry) && node['commvault']['cache'][entry].key?('timestamp')
        return node['commvault']['cache'][entry]['timestamp']
      end
      nil
    end

    def cache_save(entry, filters)
      # We absolutely require filters to be of type Array
      raise '[CommVault::Cache::cache_get] input filters needs to be of type Array' unless filters.instance_of?(Array)

      cache_file = File.join(Chef::Config['file_cache_path'], 'commvault_cache.json')

      node.default['commvault']['cache'][entry]['signature'] = Digest::SHA256.hexdigest(filters.join('::'))
      node.default['commvault']['cache'][entry]['timestamp'] = Time.now.getutc.to_i

      Chef::Log.debug "Cache file: [#{cache_file}]"
      File.open(cache_file, 'w') do |f|
        f.write(JSON.pretty_generate(node['commvault']['cache']))
      end
    end

    def cache_delete
      cache_file = File.join(Chef::Config['file_cache_path'], 'commvault_cache.json')
      return unless File.exist?(cache_file)
      File.unlink(cache_file)
      Chef::Log.debug "Deleted cache file [#{cache_file}]"
    end
  end
end
