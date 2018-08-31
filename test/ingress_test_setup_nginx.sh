#!/bin/bash
# 1. 创建一个普通 service
# 2. 创建 nginx backend service 用于显示 404 error 和实现 health api
cat << EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: default-http-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: default-http-backend
  template:
    metadata:
      labels:
        app: default-http-backend
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: default-http-backend
        # Any image is permissable as long as:
        # 1. It serves a 404 page at /
        # 2. It serves 200 on a /healthz endpoint
        image: gcr.io/google_containers/defaultbackend:1.4
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
---
kind: Service
apiVersion: v1
metadata:
  name: default-http-backend
spec:
  selector:
    app: default-http-backend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
EOF

# 3. 创建 nginx 使用的证书
folder=${HOME}/certs
mkdir -p $folder
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${folder}/example.key -out ${folder}/example.crt -subj "/CN=api.sample.com"
openssl dhparam -out ${folder}/dhparam.pem 2048
kubectl create secret tls ingress-tls-certificate --key ${folder}/example.key --cert ${folder}/example.crt
kubectl create secret generic tls-dhparam --from-file=${folder}/dhparam.pem

# 4. 创建 ingress controller 服务，nginx 已经包含在 pod 里了，不需要单独部署。我使用了 NodePort 类型的 service，其实使用 LB 类型更合理。
cat << 'EOF' | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-ingress-controller
spec:
  replicas: 1
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      k8s-app: nginx-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: nginx-ingress-lb
    spec:
      containers:
        - args:
            - /nginx-ingress-controller
            - "--default-backend-service=$(POD_NAMESPACE)/default-http-backend"
            - "--default-ssl-certificate=$(POD_NAMESPACE)/tls-certificate"
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          image: "gcr.io/google_containers/nginx-ingress-controller:0.9.0-beta.15"
          imagePullPolicy: Always
          livenessProbe:
            httpGet:
              path: /healthz
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            timeoutSeconds: 5
          name: nginx-ingress-controller
          ports:
            - containerPort: 80
              name: http
              protocol: TCP
            - containerPort: 443
              name: https
              protocol: TCP
          volumeMounts:
            - mountPath: /etc/nginx-ssl/dhparam
              name: tls-dhparam-vol
      terminationGracePeriodSeconds: 60
      volumes:
        - name: tls-dhparam-vol
          secret:
            secretName: tls-dhparam
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress
spec:
  type: NodePort
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
  selector:
    k8s-app: nginx-ingress-lb
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: default-admin
subjects:
  - kind: ServiceAccount
    name: default
    namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

# 5. 尝试访问 nginx，因为我没有配置任何的规则，所以默认显示404
# $ curl http://127.0.0.1:30954
# default backend - 404

# 6. 创建 ingress 规则
# cat << EOF | kubectl apply -f -
# apiVersion: extensions/v1beta1
# kind: Ingress
# metadata:
#   name: hello-world-ingress
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     nginx.org/ssl-services: "hello-world-svc"
#     ingress.kubernetes.io/ssl-redirect: "false"
# spec:
#   tls:
#     - hosts:
#       - api.sample.com
#       secretName: ingress-tls-certificate
#   rules:
#   - host: api.sample.com
#     http:
#       paths:
#       - path: /
#         backend:
#           serviceName: hello-world-svc
#           servicePort: 8080
# EOF

# 7. 编辑 /etc/hosts，配置到api.sample.com域名的映射，因为我是在 master 上访问，直接使用127.0.0.1
# cat << EOF >> /etc/hosts
# 127.0.0.1 api.sample.com
# EOF

# 8. 访问域名，分别测试 http 和 https
# $ curl http://api.sample.com:31509
# hello-world-deployment-78d55b99f4-dhfr5
# $ curl https://api.sample.com:31330 --cacert ${folder}/example.crt
# hello-world-deployment-78d55b99f4-dhfr5
