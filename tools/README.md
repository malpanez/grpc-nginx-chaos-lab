### Baseline
`scp root@192.168.50.100:/var/log/nginx/grpc_access.log /tmp/grpc_access_baseline.log
./tools/analyze_nginx_logs.py /tmp/grpc_access_baseline.log --label baseline`

### After chaos_slow_one
`scp root@192.168.50.100:/var/log/nginx/grpc_access.log /tmp/grpc_access_slow.log
./tools/analyze_nginx_logs.py /tmp/grpc_access_slow.log --label chaos_slow_one`
