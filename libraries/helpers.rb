# Cookbook:: commvault
# Library:: helpers

require 'socket'
require 'timeout'

module CommVault
  module Helpers
    def cvlt_already_installed?
      if platform?('windows')
        if registry_key_exists?('HKLM\SOFTWARE\CommVault Systems\Galaxy\Instance001') && registry_key_exists?('HKLM\SOFTWARE\CommVault Systems\Galaxy\Instance001\CommServe')
          Chef::Log.error 'Installation was succesful, however registration has not succeeded it seems' unless registry_data_exists?('HKLM\SOFTWARE\CommVault Systems\Galaxy\Instance001\CommServe', name: 'bCSConnectivityAvailable', type: :dword, data: 1)
          return true
        end
      end
      unless platform?('windows')
        if Dir.exist?('/etc/CommVaultRegistry/Galaxy/Instance001') && File.exist?('/etc/CommVaultRegistry/Galaxy/Instance001/CommServe/.properties')
          Chef::Log.error 'Installation was succesful, however registration has not succeeded it seems' if File.readlines('/etc/CommVaultRegistry/Galaxy/Instance001/CommServe/.properties').grep(/bCSConnectivityAvailable 1/).empty?
          return true
        end
      end
      Chef::Log.debug '[cvlt_already_installed] Returning false'
      false
    end

    # Function to check if a fqdn and port are accessible
    def cvlt_port_open?(ip_addr, port)
      begin
        Timeout.timeout(30) do
          begin
            s = TCPSocket.new(ip_addr, port)
            s.close
            return true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Errno::ETIMEDOUT
            Chef::Log.error "Can not open socket at: '#{ip_addr}:#{port}'"
            return false
          end
        end
      rescue Timeout::Error
        Chef::Log.error "Timeout on open socket at: '#{ip_addr}:#{port}'"
      end

      false
    end

    # Function to check if a registration was succesful
    def cvlt_registered?
      if platform?('windows')
        if registry_key_exists?('HKLM\SOFTWARE\CommVault Systems\Galaxy\Instance001') && registry_key_exists?('HKLM\SOFTWARE\CommVault Systems\Galaxy\Instance001\CommServe')
          return true if registry_data_exists?('HKLM\SOFTWARE\CommVault Systems\Galaxy\Instance001\CommServe', name: 'bCSConnectivityAvailable', type: :dword, data: 1)
        end
      end
      unless platform?('windows')
        if Dir.exist?('/etc/CommVaultRegistry/Galaxy/Instance001') && File.exist?('/etc/CommVaultRegistry/Galaxy/Instance001/CommServe/.properties')
          unless File.readlines('/etc/CommVaultRegistry/Galaxy/Instance001/CommServe/.properties').grep(/bCSConnectivityAvailable 1/).empty?
            return true
          end
        end
      end
      Chef::Log.debug '[cvlt_registered] Returning false'
      false
    end
  end
end
