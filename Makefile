SHELL := /bin/bash

.EXPORT_ALL_VARIABLES:

KUBECONFIG = /tmp/custom-serving-demo-gitops

.PHONY: all
all: bootstrap

.PHONY: login
login:
	rm -f $(KUBECONFIG)
	$(MAKE) $(KUBECONFIG)

$(KUBECONFIG): creds.env
	@source creds.env; oc login -u "$$USER" -p "$$PASSWORD" "$$CLUSTER"

.PHONY: bootstrap
bootstrap: $(KUBECONFIG)
	oc apply -k bootstrap/ || \
		while [ "$$(oc get subscription.operators -n openshift-operators openshift-gitops-operator -ojsonpath='{.status.state}')" != "AtLatestKnown" ]; do sleep 5; done; oc apply -k bootstrap/ || \
		while ! oc get namespace openshift-gitops; do sleep 5; done; oc apply -k bootstrap/

.PHONY: already-have-rhods
already-have-rhods: $(KUBECONFIG)
	oc apply -k bootstrap/overlays/already-have-rhods/ || \
		while [ "$$(oc get subscription.operators -n openshift-operators openshift-gitops-operator -ojsonpath='{.status.state}')" != "AtLatestKnown" ]; do sleep 5; done; oc apply -k bootstrap/overlays/already-have-rhods/ || \
		while ! oc get namespace openshift-gitops; do sleep 5; done; oc apply -k bootstrap/overlays/already-have-rhods/

.PHONY: credentials
credentials: $(KUBECONFIG)
	@if [ -f creds.env ]; then \
		source creds.env; \
		echo "-----------------------------------"; \
		echo "OpenShift Username: $$USER"; \
		echo "OpenShift Password: $$PASSWORD"; \
		echo; \
	fi
	@if oc get route -n openshift-gitops openshift-gitops-server &>/dev/null; then \
		echo "GitOps: https://$$(oc get route -n openshift-gitops openshift-gitops-server -ojsonpath='{.status.ingress[0].host}')"; \
		echo "  User: admin"; \
		echo "  Pass: $$(oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)"; \
	fi
	@if oc get route -n redhat-ods-applications rhods-dashboard &>/dev/null; then \
		echo "" ; \
		echo "RHODS: https://$$(oc get route -n redhat-ods-applications rhods-dashboard -ojsonpath='{.status.ingress[0].host}')"; \
	fi
	@if oc get route -n serving-demo-gitops minio-console &>/dev/null; then \
		echo; \
		echo "Minio Console : https://$$(oc get route -n serving-demo-gitops minio-console -ojsonpath='{.status.ingress[0].host}')"; \
		echo "Minio User    : $$(oc get secret aws-connection-minio -n serving-demo-gitops -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d) "; \
		echo "Minio Password: $$(oc get secret aws-connection-minio -n serving-demo-gitops -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d) "; \
		echo; \
	fi
