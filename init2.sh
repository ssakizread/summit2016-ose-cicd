#!/bin/bash

set -e

SCRIPT_BASE_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Login Information
OSE_CLI_USER="ose-admin"
OSE_CLI_PASSWORD="openshift"
OSE_CLI_HOST="https://gbosht01.fw.teknoloji.com.tr:8443"

CUSTOM_BASE_IMAGE_PROJECT="custom-base-image"

OSE_CI_PROJECT="cicd-ci"
OSE_API_APP_DEV="cicd-api-app-dev"
OSE_API_APP_UAT="cicd-api-app-uat"
OSE_API_APP_PROD="cicd-api-app-prod"
OSE_ENTERPRISE_RESOURCES="cicd-enterprise-resources"
SHARED_RESOURCES_ROLE="cicd-shared-resource-viewer"


POSTGRESQL_USER="postgresql"
POSTGRESQL_PASSWORD="password"
POSTGRESQL_DATABASE="gogs"
GOGS_ADMIN_USER="gogs"
GOGS_ADMIN_PASSWORD="osegogs"


function wait_for_running_build() {
    APP_NAME=$1
    NAMESPACE=$2
    BUILD_NUMBER=$3

    [ ! -z "$3" ] && BUILD_NUMBER="$3" || BUILD_NUMBER="1"

    set +e

    while true
    do
        BUILD_STATUS=$(oc get builds ${APP_NAME}-${BUILD_NUMBER} -n ${NAMESPACE} --template='{{ .status.phase }}')

        if [ "$BUILD_STATUS" == "Running" ] || [ "$BUILD_STATUS" == "Complete" ] || [ "$BUILD_STATUS" == "Failed" ]; then
           break
        fi
    done

    set -e

}

function wait_for_endpoint_registration() {
    ENDPOINT=$1
    NAMESPACE=$2
    
    set +e
    
    while true
    do
        oc get ep $ENDPOINT -n $NAMESPACE -o yaml | grep "\- addresses:" >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            break
        fi
        
        sleep 10
        
    done

    set -e
}

echo
echo "Beginning setup of demo environmnet..."
echo

# Login to OSE
oc login -u ${OSE_CLI_USER} -p ${OSE_CLI_PASSWORD} ${OSE_CLI_HOST} --insecure-skip-tls-verify=true >/dev/null 2>&1


echo
echo "Instantiating the application and associated dependencies in the ${OSE_API_APP_DEV} project..."
echo
oc process -f "$SCRIPT_BASE_DIR/support/templates/app-template.json" -v=CUSTOM_BASE_IMAGE_TAG=1.0,APPLICATION_NAME=ose-api-app,IMAGE_STREAM_NAMESPACE=${OSE_ENTERPRISE_RESOURCES} | oc -n ${OSE_API_APP_DEV} create -f- >/dev/null 2>&1


oc project ${OSE_API_APP_UAT} >/dev/null 2>&1

echo
echo "Instantiating the application and associated dependencies in the ${OSE_API_APP_UAT} project..."
echo
oc process -f "$SCRIPT_BASE_DIR/support/templates/app-template.json" -v=APPLICATION_NAME=ose-api-app,IMAGE_STREAM_NAMESPACE=${OSE_ENTERPRISE_RESOURCES} | oc create -n ${OSE_API_APP_UAT} -f-  >/dev/null 2>&1

# Delete BuildConfig object as it is not needed in this project
echo
echo "Deleting BuildConfig in the ${OSE_API_APP_UAT} project..."
echo
oc delete bc ose-api-app -n ${OSE_API_APP_UAT} >/dev/null 2>&1


oc project ${OSE_API_APP_PROD} >/dev/null 2>&1

echo
echo "Instantiating the application and associated dependencies in the ${OSE_API_APP_PROD} project..."
echo
oc process -f "$SCRIPT_BASE_DIR/support/templates/app-template.json" -v=APPLICATION_NAME=ose-api-app,IMAGE_STREAM_NAMESPACE=${OSE_ENTERPRISE_RESOURCES} | oc create -n ${OSE_API_APP_PROD} -f- >/dev/null 2>&1

# Delete BuildConfig object as it is not needed in this project
echo
echo "Deleting BuildConfig in the ${OSE_API_APP_PROD} project..."
echo
oc delete bc ose-api-app -n ${OSE_API_APP_PROD} >/dev/null 2>&1

# Go back to CI project
oc project ${OSE_CI_PROJECT} >/dev/null 2>&1

echo
echo "=================================="
echo "Setup Complete!"
echo "=================================="

