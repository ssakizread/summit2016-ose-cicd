oc get projects -o name | grep 'api-app-' | xargs oc delete
oc delete project/custom-base-image
oc delete project/enterprise-resources
oc delete project/ci
