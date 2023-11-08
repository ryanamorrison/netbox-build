### What is this?
This playbook builds a standardized [netbox](https://docs.netbox.dev) instance.  It adds certbot to ensure Letsencrypt certs remain up-to-date. It uses DNS01 with Cloudflare as it assumes the instance will not be publically accessible.

The role ensures all of the following:
* ansible facts directory is configured on the host
* /etc/hosts is configured correctly
* postgres is installed and configured for netbox
* netbox tar package is downloaded and untarred
* netbox prerequisites are installed
* netbox is installed and configured correctly
* netbox UI/app has a default user of dfnadmin with the password saved in 1Pass
* a baseline nginx is installed and configured for netbox
* certbot is installed and configured for netbox
* certificates are generated and kept up-to-date with a cron job
* back and restore scripts are installed in the /backup directory and backups are managed by a cron job

### What this does not do:
* postgres replication 
* monitoring netbox 

### Prerequisites:
* the target host must have has an OS, this runbook is oriented towards Debian in general and Ubuntu 20 specifically
* the target host is listed by FQDN in the ansible inventory 
* the target host has a DNS needs an entry in cloudflare -- necessary for DNS01 tests to work with Letsencrypt
* this role has a special requirement in that it need the variable `allow_world_readable_tmpfiles` in the ansible.cfg file set to `True` for the postgres automation to work correctly
	+ the easiest thing to do is to use the provide ansible.cfg file `export ANSIBLE_CONFIG=$HOME/repos/ansible/netbox-build/ansible.cfg`
	+ this setting has security implications and probably be left as false for those playbooks that do not require it

### Sample Playbook, Inventory and Vault
`netbox-playbook.yml`:
```
---
- hosts: netbox
  become: true
  become_method: sudo

  roles:
    - { role: netbox-build }
```
`my-inventory.yml`:
```
var_service_domain: example.com
var_nb_superuser: netbox-admin
var_nb_superuser_email: netbox-admin@example.com
var_ansible_service_account_group_name: ansible
```
`my-vault.yml`:
```
var_nb_superuser_pass: admin-netbox-password
var_db_service_pass: postgre-database-password
```
### Sample command
Assuming the above requirements are met: `ansible-playbook netbox-playbook.yml -i some-inventory`

### Upgrading
Under `defaults/main.yml`, update the `var_pinned_version` variable.  Netbox runs in a python venv and the installation script is also the upgrade script.  The playbooks will install the new version once the pinned version is changed into a new venv and swap the root directory link to the latest version.  Note: database upgrades in between even minor versions can cause issues.  In those cases it may be necessary to step through a few versions to get to current (e.g. 3.0.7 -> 3.0.9 -> 3.1).
