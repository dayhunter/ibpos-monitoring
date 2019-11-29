# IBM Blockchain Platform Monitoring in Openshift

## Architecture

![Architecture](./img/arch.png)

If OLM is installed, a Prometheus operator can be deployed to a separate project. A `Prometheus` instance is required to monitor IBM Blockchain Platform. A `Grafana` deployment pulls metrics from the `Prometheus` instance

## Environment

* Openshift 3.11 cluster deployed on IBM Cloud Infrastructure
* IBM Blockchain Platform v2.1.0

## Prerequsities

Retrieving metrics from the peer and orderer requires mutual TLS authentication, so we need to generate certificate-key pairs for both the orderer organization and peer organization

1. In **IBP console**, go to **Nodes** > **org1ca** (the CA of the peer organization). Register a new user with enroll ID `monitoring` and enroll secret `monitoringpw`. Enroll this user against the **TLS Certificate Authority** and download the wallet. The file name of the wallet is assumed to be `org1monitoring.json`

2. In **IBP console**, go to **Nodes** > **osca** (the CA of the orderer organization). Register a new user with enroll ID `monitoring` and enroll secret `monitoringpw`. Enroll this user against the **TLS Certificate Authority** and download the wallet. The file name of the wallet is assumed to be `osmonitoring.json`

3. Decode the certificates and private keys:

   ```console
   jq -r .private_key org1monitoring.json | base64 --decode > org1mspmonitoring.key
   jq -r .cert org1monitoring.json | base64 --decode > org1mspmonitoring.pem
   jq -r .private_key osmonitoring.json | base64 --decode > osmspmonitoring.key
   jq -r .cert osmonitoring.json | base64 --decode > osmspmonitoring.pem
   ```

## Prometheus Deployment

1. (Optional) Create project `ibp-monitoring`

   Note: This task can skip if this project `ibp-monitoring` exists in cluster

   ```console
   oc new-project ibp-monitoring
   ```

2. (Optional) Deploy a Prometheus operator using OLM

   Note: This task can skip if this `prometheus-operator` exists in project

   Create subscription in project `ibp-monitoring`
   ![OLM](./img/olm1.png)

   Choose Prometheus Operator
   ![OLM](./img/olm2.png)

3. Create secret

   Secret name should be `<project-name>-<msp>-monitoring-secret`

   ```console
   $ oc create secret generic ibp-org1msp-monitoring-secret --from-file=./org1mspmonitoring.pem --from-file=./org1mspmonitoring.key -n ibp-monitoring
   secret/ibp-org1msp-monitoring-secret created
   $ oc create secret generic ibp-osmsp-monitoring-secret --from-file=./osmspmonitoring.pem --from-file=./osmspmonitoring.key -n ibp-monitoring
   secret/ibp-osmsp-monitoring-secret created
   ```

4. (Optional) Create `ClusterRole:

   Note: This task can skip if this ClusterRole `prometheus-ibp` exists in cluster

   ```bash
   oc apply -f clusterrole.yaml
   ```

5. Create secret for basic authentication of `Prometheus`. Remember the password set (use password: monitoring)

   Replace `<project-name> to your project

   ```bash
   htpasswd -s -c auth ibp
   oc create secret generic prometheus-<project-name>-htpasswd -n ibp-monitoring --from-file auth
   ```

6. Replace project name to config file and access to project folder

   ```bash
   bash generate-prometheus.sh <project-name>
   ```

   Example:
   ```bash
   bash generate-prometheus.sh ibp
   ```

7. Create organisation `ServiceMonitor` config file

   Verify orgname by get `MSP` and `Port` from following command

   ```bash
   oc get svc --show-labels -l orgname -n <project-name>
   ```

   Example:
   ```bash
   oc get svc --show-labels -l orgname -n ibp
   NAME                TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                       AGE       LABELS
   org1peer1-service   NodePort   172.30.246.116   <none>        7051:30445/TCP,9443:31164/TCP,8080:31137/TCP,7443:32148/TCP   49d       app.kubernetes.io/instance=ibpoeer,app.kubernetes.io/managed-by=ibp-operator,app.kubernetes.io/name=ibp,app=org1peer1,creator=ibp,helm.sh/chart=ibm-ibp,orgname=org1msp,release=operator
   org1peer3-service   NodePort   172.30.50.37     <none>        7051:31166/TCP,9443:32422/TCP,8080:32119/TCP,7443:30392/TCP   37d       app.kubernetes.io/instance=ibpoeer,app.kubernetes.io/managed-by=ibp-operator,app.kubernetes.io/name=ibp,app=org1peer3,creator=ibp,helm.sh/chart=ibm-ibp,orgname=org1msp,release=operator
   oskrgfu1-service    NodePort   172.30.213.217   <none>        7050:31787/TCP,8443:31642/TCP,8080:31558/TCP,7443:30354/TCP   49d       app.kubernetes.io/instance=ibporderer,app.kubernetes.io/managed-by=ibp-operator,app.kubernetes.io/name=ibp,app=oskrgfu1,creator=ibp,helm.sh/chart=ibm-ibp,orgname=osmsp,release=operator
   oskrgfu2-service    NodePort   172.30.100.244   <none>        7050:32626/TCP,8443:30471/TCP,8080:32475/TCP,7443:30468/TCP   49d       app.kubernetes.io/instance=ibporderer,app.kubernetes.io/managed-by=ibp-operator,app.kubernetes.io/name=ibp,app=oskrgfu2,creator=ibp,helm.sh/chart=ibm-ibp,orgname=osmsp,release=operator
   oskrgfu3-service    NodePort   172.30.181.74    <none>        7050:30008/TCP,8443:32180/TCP,8080:31279/TCP,7443:30907/TCP   49d       app.kubernetes.io/instance=ibporderer,app.kubernetes.io/managed-by=ibp-operator,app.kubernetes.io/name=ibp,app=oskrgfu3,creator=ibp,helm.sh/chart=ibm-ibp,orgname=osmsp,release=operator
   oskrgfu4-service    NodePort   172.30.120.240   <none>        7050:32427/TCP,8443:31489/TCP,8080:31176/TCP,7443:31910/TCP   49d       app.kubernetes.io/instance=ibporderer,app.kubernetes.io/managed-by=ibp-operator,app.kubernetes.io/name=ibp,app=oskrgfu4,creator=ibp,helm.sh/chart=ibm-ibp,orgname=osmsp,release=operator
   oskrgfu5-service    NodePort   172.30.9.238     <none>        7050:31280/TCP,8443:31244/TCP,8080:31171/TCP,7443:31937/TCP   49d       app.kubernetes.io/instance=ibporderer,app.kubernetes.io/managed-by=ibp-operator,app.kubernetes.io/name=ibp,app=oskrgfu5,creator=ibp,helm.sh/chart=ibm-ibp,orgname=osmsp,release=operator
   ```
 
   You will find `orgname=osmsp`, `orgname=org1msp` and port `8443`, `9443`. Replace 2 values in the command to generate Service Monitor config file.

   ```bash
   bash generate-service-monitor.sh <project-name> <msp> <port>
   ```

   Example:
   ```bash
   bash generate-service-monitor.sh ibp osmsp 8443
   bash generate-service-monitor.sh ibp org1msp 9443
   ```

8. Update `Prometheus` config

   Open prometheus config file

   ```bash
   cd proj-<project-name>
   vi prometheus.yaml
   ```

   in `secret` session replace `- <project-name>-<msp>-monitoring-secret` secret (under htpasswd) from step 3
   
   Example:
   ```
   - ibp-osmsp-monitoring-secret
   - ibp-org1msp-monitoring-secret
   ```

9. Create required `Secrets`:

   ```bash
   oc apply -f secrets.yaml
   ```

10. Create `ServiceAccount` and `ClusterRoleBinding`:

   ```bash
   oc apply -f serviceaccount.yaml
   oc apply -f clusterrolebinding.yaml
   ```

11. Create `Service` and `Route`. TLS secret for prometheus proxy will be created automatically (Refer to <https://docs.openshift.com/container-platform/3.11/dev_guide/secrets.html#service-serving-certificate-secrets)>

    ```bash
    oc apply -f service-route.yaml
    ```

12. Create `Prometheus` instance

   ```bash
   oc apply -f prometheus.yaml
   ```

13.  Create `ServiceMonitor` for Ordering service and Peer

   ```bash
   oc apply -f <msp>-servicemonitor.yaml
   ```

   Example:
   ```bash
   oc apply -f osmsp-servicemonitor.yaml
   oc apply -f org1msp-servicemonitor.yaml
   ```

14. Trigger configuration refresh manually

   ```bash
   oc exec prometheus-<project-name>-0 -c prometheus -n ibp-monitoring -- curl -X POST http://localhost:9090/-/reload
   ```

   Example:
   ```bash
   oc exec prometheus-ibp-0 -c prometheus -n ibp-monitoring -- curl -X POST http://localhost:9090/-/reload
   ```

15. Visit prometheus endpoint and login using Openshift credential. To retrieve address:
  
   ```bash
   echo "https://$(oc get routes prometheus-<project-name> -n ibp-monitoring -o json | jq -r .spec.host)"
   ```

   Example:
   ```bash
   echo "https://$(oc get routes prometheus-ibp -n ibp-monitoring -o json | jq -r .spec.host)"
   ```

16. Go to **Status** > **Targets** and a similar screen should be shown:

   ![Screenshot](./img/prom-ss.png)

## (Optional) Grafana Deployment

Note: This task can skip if Grafana exists in cluster

1. In `grafana.yaml`, search for `GF_SECURITY_ADMIN_USER` and change the value to your Openshift username

2. Deploy `Grafana`

   ```bash
   oc apply -f grafana-ibp.yaml
   ```

3. Visit grafana endpoint and login using Openshift credential. To retrieve address:
  
   ```bash
   echo "https://$(oc get routes grafana-ibp -n ibp-monitoring -o json | jq -r .spec.host)"
   ```
