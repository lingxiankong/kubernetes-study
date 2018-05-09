#!/bin/bash

# Create a service of LoadBalancer type
cat <<EOF | kubectl create -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hostname-echo-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hostname-echo
  template:
    metadata:
      labels:
        app: hostname-echo
    spec:
      containers:
        - image: "lingxiankong/alpine-test"
          imagePullPolicy: Always
          name: hostname-echo-container
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hostname-echo-svc
spec:
  ports:
     -  port: 80
        protocol: TCP
        targetPort: 8080
  selector:
    app: hostname-echo
  type: LoadBalancer
EOF
if [ $? -ne 0 ]; then
  echo "Failed to create the service!" && exit -1
fi

# Wait for 10 mins until the service gets an external ip
end=$(($(date +%s) + 600))
echo "Waiting for the service to be created..."
str='#'
while true; do
  vip=$(kubectl describe service hostname-echo-svc | grep 'LoadBalancer Ingress' | awk '{print $3}')
  if [ "x$vip" != "x" ]; then
    printf "%-100s]\r\n" "$str"
    echo "Service is created successfully, vip: $vip"
    break
  fi

  if [ ${#str} -ge 100 ]; then
    printf "%-100s]\r\n" "$str"
    str='#'
  else
    printf "%-100s]\r" "$str"
    str+="#"
  fi

  sleep 1
  now=$(date +%s)
  [ $now -gt $end ] && echo "Failed to wait for service created in time" && exit -1
done

# Send http request to the external ip
hostname=$(curl -s http://${vip})
if [ $? -ne 0 ]; then
  echo "\nFailed to access the service!" && exit -1
fi

if [[ $hostname =~ ^hostname-echo-deployment.* ]]; then
  echo "Got correct response from the service!"
  kubectl delete service hostname-echo-svc
  kubectl delete deploy hostname-echo-deployment
elif []; then
  echo "Got wrong response from the service!" && exit -1
fi

