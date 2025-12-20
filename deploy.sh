#!/usr/bin/env bash
set -e

echo "Building uberjar..."
clojure -T:build ci

echo ""
echo "Copying JAR as ZIP (JAR is already a ZIP format)..."
cp target/net.clojars.surt666/lambda-test-0.1.0-SNAPSHOT.jar target/lambda.zip

echo ""
echo "Deploying to AWS..."
sam deploy

echo ""
echo "Deployment complete!"
