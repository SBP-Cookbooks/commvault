# commvault CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## 0.4.0

- bug fix for overriding plan content. Somehow `fsIncludeFilterOperationType` at anything else than 3 will trigger a "duplicate content warning"
- replace File.open with File.write

## 0.3.2

- Added feature to provide bash environment variables to the install resource. This provides a way to influence the CommVault installer to change the TMP DIR

## 0.3.1

- Fix a bug with the working directory for the installation bash entry (/tmp might be noexec)

## 0.3.0

- Start of change log
