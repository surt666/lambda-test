#!/usr/bin/env bash
set -e

echo "Building uberjar (skipping tests)..."
clojure -T:build uber

echo ""
echo "Copying JAR as ZIP (JAR is already a ZIP format)..."
cp target/net.clojars.surt666/lambda-test-0.1.0-SNAPSHOT.jar target/lambda.zip

echo ""
echo "Deploying to AWS..."
sam deploy --no-confirm-changeset

echo ""
echo "Deployment complete!"
