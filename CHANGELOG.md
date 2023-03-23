# commvault CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## 1.0.0

- replace File.open with File.write
- Commvault has changed the way it handles `restore only` installations and we therefor need to register the fs agent post instllation now
- Add support for plan rules in a way that `plan_name` can be empty and it waits for plan rules to execute
- Add some logic to wait for cache to populate on the Commvault side to get the client id
- Add support for 'registering' the file system agent as Commvault made it optional in 11.23

## 0.3.2

- Added feature to provide bash environment variables to the install resource. This provides a way to influence the CommVault installer to change the TMP DIR

## 0.3.1

- Fix a bug with the working directory for the installation bash entry (/tmp might be noexec)

## 0.3.0

- Start of change log
