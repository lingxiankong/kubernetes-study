# 安装
helm install stable/nginx-ingress --name nginx-ingress-controller --set rbac.create=true

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml

# 创建 nginx 使用的证书
folder=${HOME}/certs
mkdir -p $folder
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${folder}/example.key -out ${folder}/example.crt -subj "/CN=api.sample.com"
openssl dhparam -out ${folder}/dhparam.pem 2048
kubectl create secret tls ingress-tls-certificate --key ${folder}/example.key --cert ${folder}/example.crt
kubectl create secret generic tls-dhparam --from-file=${folder}/dhparam.pem

# 测试
cat <<EOF | k apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-nginx-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  backend:
    serviceName: nginx-ingress-controller-default-backend
    servicePort: 80
  rules:
  - host: nginx.sample.com
    http:
      paths:
      - path: /index
        backend:
          serviceName: hello
          servicePort: 8080
  # test port name
  - host: nginx.sample1.com
    http:
      paths:
      - path: /index
        backend:
          serviceName: hello
          servicePort: http-port
  # test no path
  - host: nginx.sample2.com
    http:
      paths:
      - backend:
          serviceName: hello
          servicePort: 8080
EOF

sed -i "/$ip/d" /etc/hosts
url=nginx.sample.com
url1=nginx.sample1.com
url2=nginx.sample2.com
ip=172.24.4.2
cat <<EOF >> /etc/hosts
$ip $url
$ip $url1
$ip $url2
EOF
curl http://$url/index
curl http://$url1/index
curl http://$url2
