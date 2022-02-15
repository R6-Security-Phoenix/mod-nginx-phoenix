# NGINX ingress plugin

## Initial env

kubectl config use-context nginx

```
# start a k8s cluster
minikube start --kubernetes-version=v1.21.0 --profile nginx --vm=true
# on mac it's better to use --driver=hyperkit

# install nginx ingress
minikube addons enable ingress --profile nginx

# example app which echoes the requests it receives
kubectl create deployment example-app --image=mendhak/http-https-echo:19

# NodePort service
kubectl expose deployment example-app --type=NodePort --port=8080

# ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-app
                port:
                  number: 8080
EOF
```

### If there's an error during ingress creation

```
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
# and rerun the previous kubectl apply for the ingress
```

### Test the ingress for the example app

```
curl $(minikube ip --profile nginx)
```

## Plugin development

Path where the plugins should reside: `/etc/nginx/lua/plugins/`

The name of the lua file with the entrypoint must be `main.lua`

Example: 

`/etc/nginx/lua/plugins/hello/main.lua`

[ngx lua module documentation](https://github.com/openresty/lua-nginx-module)

## Development cycle:

```
# enter the nginx pod
kubectl exec -it -n ingress-nginx deploy/ingress-nginx-controller -- bash

# edit the example plugin 
nano /etc/nginx/lua/plugins/hello_world/main.lua

# reload nginx to take effect
nginx -s reload

# monitor nginx for logs
kubectl logs -f -n ingress-nginx deploy/ingress-nginx-controller
```

## Deploying the plugin

```
# create configmap from the lua file
kubectl create configmap -n ingress-nginx plugin-demo --from-file=main.lua

# edit the existing deployment
kubectl edit -n ingress-nginx deploy/ingress-nginx-controller

# add the volume mount to the nginx container
# kubectl edit -n ingress-nginx deploy/ingress-nginx-controller
volumeMounts:
- name: plugin-demo
    mountPath: /etc/nginx/lua/plugins/plugin_demo/

# create the volume from the configmap for the deployment
volumes:
- name: plugin-demo
  configMap:
    name: plugin-demo
    items:
    - key: main.lua
      path: main.lua

# edig the nginx-ingress role
kubectl edit role -n ingress-nginx ingress-nginx

# add permission to delete pods
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
  - delete # additional permission
```

The deployment/role can't be patched in a easily with a static configuration, but an operator could do it.

## enable plugin

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  plugins: plugin_demo
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
EOF
```

## test the plugin

```
curl -H "User-Agent: secret" $(minikube ip --profile nginx)
```

## Cleanup

```
minikube addons disable ingress --profile nginx
```
