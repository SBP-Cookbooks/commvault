# CommVault

Chef cookbook that installs and configures a CommVault agent.

CommVault is a Data Management solution and this cookbook provides resources to install and configure a CommVault agent.

This cookbook is built using the new terminology and thus requires the use of the authorization code and plans.

Legacy Storage Policies and user/pass is not supported and should not be used

To create the install packages download the installer and create a custom package.
The only needed packages are FS Core and FS Advanced

* Source: <https://github.com/sbp-cookbooks/commvault>
* Binaries: <https://github.com/sbp-cookbooks/commvault/releases>

## Requirements

* Chef 14.0+
* CommVault 11.0 SP28 (2022E) +

### Platforms

* RHEL 7+, CentOS7+
* RHEL 8+, CentOS8+
* DEBIAN 12+
* Windows 2012, 2012 r2
* Windows 2016
* Windows 2019

## Resources

### commvault_install

| Name                     | Type                    | Default                    | Description                                                                                                                                   |
| -------------------------| ------------------------| ---------------------------| --------------------------------------------------------------------------------------------------------------------------------------------- |
| auth_code                | String                  | N/A                        | The authorization code (either global CommCell or company/tenant)                                                                             |
| cs_name                  | String                  | N/A                        | The client name of the CommServe                                                                                                              |
| cs_fqdn                  | String                  | N/A                        | The Fully Qualified Domain Name of the CommServe                                                                                              |
| plan_name                | [String, nil]           | nil                        | The plan name to be used for this installation (optional, left out assumes you use plan rules or manual assignment)                           |
| licensed                 | [TrueClass, FalseClass] | false                      | Whether a client should be licensed on installation, by default assumes restore only is wanted                                                |
| proxies                  | Array                   | []                         | An array of proxies to connect to (connections directly to CommServe are not supported), this expects a hash of fqdn and name per array entry |
| registration_timeout     | Integer                 | 600                        | Timeout to wait for a succesful registration                                                                                                  |
| install_dir_windows      | String                  | C:\Windows\Temp\CVInstall  | Location we use to store files and configurations used for installation on windows                                                            |
| install_dir_linux        | String                  | /opt/CVInstall             | Location we use to store files and configurations used for installation on Linux                                                              |
| install_windows          | String                  | ''                         | This is the location (URL) were we get the .zip package to use during the installation (needs to be FS Core and FS Advanced) on windows       |
| install_windows_checksum | [String, nil]           | nil                        | Checksum to verify the file located at the url on windows                                                                                     |
| install_linux            | String                  | ''                         | This is the location (URL) were we get the .tar package to use during the installation (needs to be FS Core and FS Advanced) on Linux         |
| install_linux_checksum   | [String, nil]           | nil                        | Checksum to verify the file located at the url on windows                                                                                     |
| bash_env_variables       | [Hash, nil]             | nil                        | Expose option to send extra environment variables to bash commands                                                                            |

#### Example

```ruby
commvault_instance 'Instance001' do
  package_linux 'https://some.url/CommVault_SP18_Linux.tar'
  package_windows 'https://some.url/CommVault_SP18_Windows.zip'
  auth_code '3SAFB5CA'
  cs_name 'cell01'
  cs_fqdn 'cell01.some.url'
  proxies [ { 'name': 'proxy01', 'fqdn': 'proxy01.some.url' }, { 'name': 'proxy02', 'fqdn': 'proxy02.some.url' } ]
end
```

### commvault_fs_subclient

| Name                     | Type                    | Default                    | Description                                                                                                                         |
| -------------------------| ------------------------| ---------------------------| ------------------------------------------------------------------------------------------------------------------------------------|
| endpoint                 | String                  | N/A                        | The CommVault API endpoint to connect to (URL)                                                                                      |
| subclient_name           | String                  | default                    | This is the subclient name for the File System agent we need to manage, only 'default' is supported currently                       |
| filters                  | Array                   | []                         | An array of Strings which should be considered exclusions                                                                           |
| use_cache                | [TrueClass, FalseClass] | true                       | By default this cookbook does caching to limit hammering of the API, but with this you can disable it                               |
| cache_timeout            | Integer                 | 43200                      | The time to live for cache entries before we talk to the API again                                                                  |
| use_local_login          | [TrueClass, FalseClass] | true                       | By default we use local qlogin with localadmin impersonation, if you would like to add user/pass set this to false                  |
| plan_name                | [String, nil]           | nil                        | Can be used to assign a plan if at any point a client is switched from unmanaged to managed                                         |
| login_user               | String                  | N/A                        | If use_local_login is false this is the user to use for authentication against the endpoint                                         |
| login_pass               | String                  | N/A                        | If use_local_login is false this is the password to use for authentication against the endpoint                                     |
| systemstate              | [TrueClass, FalseClass] | true                       | Determines if systemstate should be included in the backup                                                                          |

#### Example

```ruby
commvault_fs_subclient 'default' do
  endpoint 'https://api.some.url/webconsole/api'
  subclient_name 'default'
  filters %w(C:\Temp /tmp)
end
```

## License & Authors

* Author:: Mike van Goor ([mvangoor@schubergphilis.com](mailto:mvangoor@schubergphilis.com))

```text
Copyright: Schuberg Philis

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
