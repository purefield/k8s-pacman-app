# import logins
. /srv/login.sh
oc-login 1

# names
cluster1="local-cluster"
cluster2=$(echo ${clusters[2]} | cut -d\. -f1)
cluster3=$(echo ${clusters[3]} | cut -d\. -f1)

# in ACM label each cluster with their clustername:cluster1,...
#                                      clusterid=cluster1,... 
oc label ManagedCluster -l name=$cluster1 clusterid=cluster1    --overwrite=true
oc label ManagedCluster -l name=$cluster1 clustername=cluster1  --overwrite=true
oc label ManagedCluster -l name=$cluster2 clusterid=cluster2    --overwrite=true
oc label ManagedCluster -l name=$cluster2 clustername=cluster2  --overwrite=true
oc label ManagedCluster -l name=$cluster3 clusterid=cluster3    --overwrite=true
oc label ManagedCluster -l name=$cluster3 clustername=cluster3  --overwrite=true

# install haproxy
oc-login 1
cd haproxy
oc delete --ignore-not-found=1 -f namespace.yaml
oc apply -f namespace.yaml
HAPROXY_LB_ROUTE=pacman-app-lb.$(oc get ingresses.config.openshift.io cluster -o jsonpath='{ .spec.domain }')
oc -n pacman-app-lb create route edge pacman-app-lb \
   --service=pacman-app-lb-service --port=8080 --insecure-policy=Allow \
   --hostname=${HAPROXY_LB_ROUTE}
echo $HAPROXY_LB_ROUTE
# Define the variable of `PACMAN_INGRESS`
PACMAN_INGRESS=pacman-ingress.$(oc get ingresses.config.openshift.io cluster -o jsonpath='{ .spec.domain }')
# Define the variable of `PACMAN_CLUSTER1`
oc-login 1
PACMAN_CLUSTER1=pacman-pacman-app.$(oc get ingresses.config.openshift.io cluster -o jsonpath='{ .spec.domain }')
# Define the variable of `PACMAN_CLUSTER2`
oc-login 2
PACMAN_CLUSTER2=pacman-pacman-app.$(oc get ingresses.config.openshift.io cluster -o jsonpath='{ .spec.domain }')
# Define the variable of `PACMAN_CLUSTER3`
oc-login 3
PACMAN_CLUSTER3=pacman-pacman-app.$(oc get ingresses.config.openshift.io cluster -o jsonpath='{ .spec.domain }')
# Copy the sample configmap
rm -f haproxy; cp haproxy.tmpl haproxy
# Update the HAProxy configuration
sed -i "/option httpchk GET/a \ \ \ \ http-request set-header Host ${PACMAN_INGRESS}" haproxy
# Replace the value with the variable `PACMAN_INGRESS`
sed -i "s/<pacman_lb_hostname>/${PACMAN_INGRESS}/g" haproxy
# Replace the value with the variable `PACMAN_CLUSTER1`
sed -i "s/<server1_name> <server1_pacman_route>:<route_port>/cluster1 ${PACMAN_CLUSTER1}:80/g" haproxy
# Replace the value with the variable `PACMAN_CLUSTER2`
sed -i "s/<server2_name> <server2_pacman_route>:<route_port>/cluster2 ${PACMAN_CLUSTER2}:80/g" haproxy
# Replace the value with the variable `PACMAN_CLUSTER3`
sed -i "s/<server3_name> <server3_pacman_route>:<route_port>/cluster3 ${PACMAN_CLUSTER3}:80/g" haproxy
# Create the configmap
oc-login 1
oc -n pacman-app-lb create configmap haproxy --from-file=haproxy
# create haproxy and check it
oc -n pacman-app-lb create -f haproxy-clusterip-service.yaml
oc -n pacman-app-lb create -f haproxy-deployment.yaml
oc -n pacman-app-lb get pods
PACMAN_LB_ROUTE=$(oc -n pacman-app-lb get route pacman-app-lb -o jsonpath='{.status.ingress[*].host}')
curl -k https://${PACMAN_LB_ROUTE}
cd -

# create application
oc delete -f pacman-app.yaml
oc apply -f pacman-app.yaml
