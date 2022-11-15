# Resource: commvault_instance

include CommVault::Api
include CommVault::Cache
include CommVault::Helpers

provides :commvault_instance

unified_mode true if respond_to? :unified_mode

# rubocop:disable ChefModernize/PowershellScriptExpandArchive

default_action :install

# Properties
property :auth_code, String
property :cs_name, String
property :cs_fqdn, String
property :plan_name, String
property :proxies, Array, default: []
property :registration_timeout, Integer, default: 600 # 10 minutes

# Installation directories
property :install_dir_windows, String, default: 'C:\Windows\Temp\CVInstall'
property :install_dir_linux, String, default: '/opt/CVInstall'

# Packages
property :package_windows, String, default: ''
property :package_windows_checksum, [String, nil]
property :package_linux, String, default: ''
property :package_linux_checksum, [String, nil]

# Environment variables
property :bash_env_variables, [Hash, nil], default: nil

action :install do
  raise 'Please enter correct auth_code' if new_resource.auth_code.empty?

  if cvlt_already_installed?
    Chef::Log.info 'Instance is already installed'
    return
  end

  if platform?('windows')
    # Temporary location of package to download
    tmp_package = "#{new_resource.install_dir_windows}\\package.zip"
    tmp_xml = "#{new_resource.install_dir_windows}\\install.xml"

    # Create the installation directory
    directory new_resource.install_dir_windows do
      path new_resource.install_dir_windows
      recursive true
      action :create
    end

    # Download the package
    remote_file tmp_package do
      path tmp_package
      source new_resource.package_windows
      checksum new_resource.package_windows_checksum unless new_resource.package_windows_checksum.nil?
      notifies :delete, "directory[#{new_resource.install_dir_windows}\\pkg]", :immediately
      notifies :run, 'powershell_script[unpack_package]', :immediately
      action :create
    end

    # Clean the target directory
    directory "#{new_resource.install_dir_windows}\\pkg" do
      ignore_failure true
      recursive true
      action :nothing
    end

    # Extract the package
    powershell_script 'unpack_package' do
      cwd new_resource.install_dir_windows
      code "Expand-Archive #{tmp_package} -DestinationPath #{new_resource.install_dir_windows}\\pkg"
      action :nothing
    end

    # Place an install.xml with our defaults as the default version has wrong defaults.
    # This should be addressed in a future release, making this obsolete...
    template tmp_xml do
      source 'install_windows.xml'
      cookbook 'commvault'
    end

    installed = false
    # Install the software (silent)
    new_resource.proxies.each do |proxy|
      # We first check if we can access the defined proxy
      next unless cvlt_port_open?(proxy[:fqdn], 8403)

      # Perform the installation
      install_command = if new_resource.plan_name.nil? || new_resource.plan_name.empty?
                          "#{new_resource.install_dir_windows}\\pkg\\setup.exe /silent /play #{tmp_xml} /authcode #{new_resource.auth_code} /fwtype 2 /cshostname #{new_resource.cs_fqdn} /csclientname #{new_resource.cs_name} /proxyhostname #{proxy[:fqdn]} /proxyclientname #{proxy[:name]} /tunnelport 8403"
                        else
                          "#{new_resource.install_dir_windows}\\pkg\\setup.exe /silent /play #{tmp_xml} /authcode #{new_resource.auth_code} /fwtype 2 /cshostname #{new_resource.cs_fqdn} /csclientname #{new_resource.cs_name} /proxyhostname #{proxy[:fqdn]} /proxyclientname #{proxy[:name]} /tunnelport 8403 /plan #{new_resource.plan_name}"
                        end
      powershell_script "Install CommVault #{proxy[:name]}" do
        code install_command
      end

      installed = true
      # Only do one installation
      break
    end
  else
    # Temporary location of package to download
    tmp_package = "#{new_resource.install_dir_linux}/package.tar.gz"
    tmp_xml = "#{new_resource.install_dir_linux}/install.xml"

    # Some systems lack tar in their minimal install
    package 'tar'

    # Create the installation directory
    directory new_resource.install_dir_linux do
      path new_resource.install_dir_linux
      mode '0700'
      recursive true
      action :create
    end

    # Download the package
    remote_file tmp_package do
      path tmp_package
      source new_resource.package_linux
      checksum new_resource.package_linux_checksum unless new_resource.package_linux_checksum.nil?
      mode '0600'
      notifies :delete, "directory[#{new_resource.install_dir_linux}/pkg]", :immediately
      notifies :run, 'bash[unpack_package]', :immediately
      action :create
    end

    # Clean the target directory
    directory "#{new_resource.install_dir_linux}/pkg" do
      ignore_failure true
      recursive true
      action :nothing
    end

    # Extract the package
    bash 'unpack_package' do
      cwd new_resource.install_dir_linux
      code "tar xf #{tmp_package}"
      environment new_resource.bash_env_variables unless new_resource.bash_env_variables.nil?
      action :nothing
    end

    # Place an install.xml with our defaults as the default version has wrong defaults.
    # This should be addressed in a future release, making this obsolete...
    template tmp_xml do
      source 'install_linux.xml'
      cookbook 'commvault'
      mode '0644'
    end

    installed = false
    # Install the software (silent)
    new_resource.proxies.each do |proxy|
      # We first check if we can access the defined proxy
      next unless cvlt_port_open?(proxy[:fqdn], 8403)

      # Perform the installation
      bash "Install CommVault #{proxy[:name]}" do
        cwd new_resource.install_dir_linux
        code "./pkg/silent_install -p #{tmp_xml} -authcode #{new_resource.auth_code} -cshost #{new_resource.cs_fqdn} -fwtype 2 -csclientname #{new_resource.cs_name} -proxyhost #{proxy[:fqdn]} -proxyclientname #{proxy[:name]} -tunnelport 8403 -plan #{new_resource.plan_name}"
        environment new_resource.bash_env_variables unless new_resource.bash_env_variables.nil?
      end

      installed = true
      # Only do one installation
      break
    end
  end

  # If above did not succeed we break here
  raise 'No connection possible to any proxies' unless installed

  # Delete cache if it exists
  ruby_block 'Cache delete' do
    block do
      cache_delete()
    end
  end

  # Check registration
  ruby_block 'Check registration success' do
    block do
      now = Time.now.to_i
      until cvlt_registered?
        diff = Time.now.to_i - now
        Chef::Log.info "Sleeping 30 seconds (untill #{new_resource.registration_timeout} seconds timeout) for registration to finish"
        sleep(10)
        sleep(20) if diff >= 60
        puts "We have been waiting for #{diff} seconds for registration success" if diff >= 2
        break if diff >= new_resource.registration_timeout
      end
      unless cvlt_registered?
        puts "CommVault registration unsuccesful after #{new_resource.registration_timeout} seconds, uninstalling"
        # Call uninstall
      end
    end
  end
end
