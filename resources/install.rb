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
property :plan_name, [String, nil]
property :licensed, [true, false], default: false
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

  if new_resource.licensed == false && !new_resource.plan_name.nil?
    Chef::Log.error 'licensed property is false and you provided a plan_name, this is an inconsistent configuration setup'
    Chef::Log.error 'Please either ensure licensed is true and/or remove the plan_name input'
    Chef::Log.error 'Note we will not install the Commvault software untill this is resolved.'
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
      variables(
        licensed: new_resource.licensed
      )
    end

    installed = false
    # Install the software (silent)
    new_resource.proxies.each do |proxy|
      # We first check if we can access the defined proxy
      next unless cvlt_port_open?(proxy[:fqdn], 8403)

      # Perform the installation
      if new_resource.plan_name.nil?
        powershell_script "Install CommVault #{proxy[:name]} with plan #{new_resource.plan_name}" do
          code "#{new_resource.install_dir_windows}\\pkg\\setup.exe /silent /play #{tmp_xml} /authcode #{new_resource.auth_code} /fwtype 2 /proxyhostname #{proxy[:fqdn]} /proxyclientname #{proxy[:name]} /tunnelport 8403"
        end
      else
        powershell_script "Install CommVault #{proxy[:name]}" do
          code "#{new_resource.install_dir_windows}\\pkg\\setup.exe /silent /play #{tmp_xml} /authcode #{new_resource.auth_code} /fwtype 2 /proxyhostname #{proxy[:fqdn]} /proxyclientname #{proxy[:name]} /tunnelport 8403 /plan #{new_resource.plan_name}"
        end
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
      notifies :delete, "directory[#{new_resource.install_dir_linux}/Unix]", :immediately
      notifies :run, 'bash[unpack_package]', :immediately
      action :create
    end

    # Clean the target directory
    directory "#{new_resource.install_dir_linux}/Unix" do
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
      variables(
        licensed: new_resource.licensed
      )
    end

    installed = false
    # Install the software (silent)
    new_resource.proxies.each do |proxy|
      # We first check if we can access the defined proxy
      next unless cvlt_port_open?(proxy[:fqdn], 8403)

      # Perform the installation
      if new_resource.plan_name.nil?
        bash "Install CommVault #{proxy[:name]} with plan #{new_resource.plan_name}" do
          cwd new_resource.install_dir_linux
          code "./Unix/silent_install -silent -p #{tmp_xml} -authcode #{new_resource.auth_code} -fwtype 2 -tunnelport 8403 -proxyhost #{proxy[:fqdn]} -proxyclientname #{proxy[:name]}"
          environment new_resource.bash_env_variables unless new_resource.bash_env_variables.nil?
        end
      else
        bash "Install CommVault #{proxy[:name]}" do
          cwd new_resource.install_dir_linux
          code "./Unix/silent_install -silent -p #{tmp_xml} -authcode #{new_resource.auth_code} -fwtype 2 -tunnelport 8403 -proxyhost #{proxy[:fqdn]} -proxyclientname #{proxy[:name]} -plan #{new_resource.plan_name}"
          environment new_resource.bash_env_variables unless new_resource.bash_env_variables.nil?
        end
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
        # TODO: Call uninstall
      end
    end
  end
end
