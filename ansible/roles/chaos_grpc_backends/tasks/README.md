### One backend down, the other still serves traffic
`ansible-playbook -i ansible/inventory/hosts.yml ansible/chaos.yml --tags chaos_kill_one`

### Restore all backends
`ansible-playbook -i ansible/inventory/hosts.yml ansible/chaos.yml --tags chaos_restore`

### Make one backend slow using tc netem
`ansible-playbook -i ansible/inventory/hosts.yml ansible/chaos.yml --tags chaos_slow_one`

### Reset network shaping and restore services
`ansible-playbook -i ansible/inventory/hosts.yml ansible/chaos.yml --tags "chaos_reset_net,chaos_restore"`

### Kill ALL backends – gateway should start returning errors
`ansible-playbook -i ansible/inventory/hosts.yml ansible/chaos.yml --tags chaos_kill_all`
